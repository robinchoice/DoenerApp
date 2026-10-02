import 'package:doener_models/doener_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'auth.dart';
import 'deps.dart';
import 'http.dart';
import 'places.dart';
import 'social.dart';

/// "Your" city is the one of the nearest known place within this distance.
const _cityRadius = 20000.0;
const _maxEntries = 100;

const _columns = {
  RatingDimension.overall: 'rating',
  RatingDimension.sauce: 'sauce_rating',
  RatingDimension.fleisch: 'fleisch_rating',
  RatingDimension.brot: 'brot_rating',
};

void mountRanking(Router router, Deps deps) {
  // GET /ranking?lat&lon&by — the rated places of the city around lat/lon
  // (by their address), best first, with the friends who rated them.
  router.get('/ranking', (Request request) async {
    final me = await requireUser(deps, request);
    final lat = queryDouble(request, 'lat');
    final lon = queryDouble(request, 'lon');
    final by = RatingDimension.values.asNameMap()[request.url.queryParameters['by'] ?? RatingDimension.overall.name];
    if (by == null) throw const ApiException.badRequest('Parameter "by" ist ungültig');
    final column = _columns[by]!;

    final nearest = await queryOne(
      deps.db,
      'SELECT city FROM places p WHERE city IS NOT NULL AND ${withinRadius('p')} ORDER BY ${distanceSql('p')} LIMIT 1',
      radiusParams(lat, lon, _cityRadius),
    );
    final city = nearest?['city'] as String?;
    if (city == null) return json(RankingDto(by: by, entries: const []).toJson());

    final rows = rankByWeight(await query(
      deps.db,
      'SELECT pv.*, s.avg, s.n FROM place_view pv JOIN ('
      '  SELECT place_id, avg($column)::float8 AS avg, count($column)::int AS n FROM reviews'
      '  WHERE $column IS NOT NULL GROUP BY place_id'
      ') s ON s.place_id = pv.id WHERE pv.city = @city',
      {'city': city},
    )).take(_maxEntries).toList();

    final friends = <String, List<FriendRatingDto>>{};
    if (rows.isNotEmpty) {
      final friendRows = await query(
        deps.db,
        '$friendIdsCte SELECT r.place_id, u.id, u.display_name, r.$column AS value FROM reviews r '
        'JOIN users u ON u.id = r.user_id WHERE r.user_id IN (SELECT id FROM friends) '
        'AND r.place_id = ANY(@ids:_uuid) AND r.$column IS NOT NULL ORDER BY lower(u.display_name)',
        {'me': me.id, 'ids': [for (final r in rows) r['id'] as String]},
      );
      for (final f in friendRows) {
        friends.putIfAbsent(f['place_id'] as String, () => []).add(FriendRatingDto(
              user: UserDto(id: f['id'] as String, displayName: f['display_name'] as String),
              rating: f['value'] as int,
            ));
      }
    }

    return json(RankingDto(city: city, by: by, entries: [
      for (final r in rows)
        RankingEntryDto(
          place: placeFromRow(r),
          average: r['avg'] as double,
          count: r['n'] as int,
          friends: friends[r['id']] ?? const [],
        ),
    ]).toJson());
  });
}
