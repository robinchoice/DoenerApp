import 'dart:math' as math;

import 'package:doener_models/doener_models.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'auth.dart';
import 'deps.dart';
import 'google_places.dart';
import 'http.dart';

const liveStatusDuration = Duration(hours: 2);
const _maxSyncSpanDeg = 0.5;

PlaceDto placeFromRow(Map<String, dynamic> row) => PlaceDto(
      placeId: row['google_place_id'] as String,
      name: row['name'] as String,
      latitude: row['latitude'] as double,
      longitude: row['longitude'] as double,
      address: row['address'] as String?,
      postalCode: row['postal_code'] as String?,
      city: row['city'] as String?,
      openingHours: row['opening_hours'] as String?,
      avgRating: row['avg_rating'] as double?,
      reviewCount: row['review_count'] as int,
      specialNote: row['special_note'] as String?,
    );

ReviewDto reviewFromRow(Map<String, dynamic> row) => ReviewDto(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      userName: row['display_name'] as String,
      placeId: row['google_place_id'] as String,
      placeName: row['place_name'] as String,
      rating: row['rating'] as int,
      sauceRating: row['sauce_rating'] as int?,
      fleischRating: row['fleisch_rating'] as int?,
      brotRating: row['brot_rating'] as int?,
      text: row['text'] as String?,
      specialNote: row['special_note'] as String?,
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
    );

VisitDto visitFromRow(Map<String, dynamic> row) => VisitDto(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      userName: row['display_name'] as String,
      placeId: row['google_place_id'] as String,
      placeName: row['place_name'] as String,
      visitedAt: row['visited_at'] as DateTime,
      comment: row['comment'] as String?,
      foodType: row['food_type'] as String?,
    );

const _reviewSelect = 'SELECT r.*, u.display_name, p.google_place_id, p.name AS place_name FROM reviews r '
    'JOIN users u ON u.id = r.user_id JOIN places p ON p.id = r.place_id';
const _visitSelect = 'SELECT v.*, u.display_name, p.google_place_id, p.name AS place_name FROM visits v '
    'JOIN users u ON u.id = v.user_id JOIN places p ON p.id = v.place_id';

Future<Map<String, dynamic>> _requirePlace(Deps deps, String placeId) async {
  final row = await queryOne(deps.db, 'SELECT * FROM place_view WHERE google_place_id = @id', {'id': placeId});
  if (row == null) throw const ApiException.notFound('Laden unbekannt');
  return row;
}

void mountPlaces(Router router, Deps deps) {
  // GET /places?minLat&minLon&maxLat&maxLon — places in the visible map area.
  router.get('/places', (Request request) async {
    final minLat = queryDouble(request, 'minLat');
    final minLon = queryDouble(request, 'minLon');
    final maxLat = queryDouble(request, 'maxLat');
    final maxLon = queryDouble(request, 'maxLon');
    if (minLat >= maxLat || minLon >= maxLon || minLat < -90 || maxLat > 90 || minLon < -180 || maxLon > 180) {
      throw const ApiException.badRequest('Ungültiger Kartenausschnitt');
    }

    final apiKey = deps.config.googlePlacesApiKey;
    if (apiKey != null && maxLat - minLat <= _maxSyncSpanDeg && maxLon - minLon <= _maxSyncSpanDeg) {
      final tiles = tilesCovering(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon);
      if (tiles.length <= maxTilesPerRequest) await Future.wait(tiles.map((t) => _syncTile(deps, apiKey, t)));
    }

    final rows = await query(
      deps.db,
      'SELECT * FROM place_view WHERE latitude BETWEEN @minLat AND @maxLat AND longitude BETWEEN @minLon AND @maxLon '
      'ORDER BY review_count DESC, name LIMIT 300',
      {'minLat': minLat, 'maxLat': maxLat, 'minLon': minLon, 'maxLon': maxLon},
    );
    return json(rows.map((r) => placeFromRow(r).toJson()).toList());
  });

  router.get('/places/top', (Request request) async {
    final lat = queryDouble(request, 'lat');
    final lon = queryDouble(request, 'lon');
    final radius = queryDouble(request, 'radius', fallback: 5000).clamp(100, 20000);
    final limit = queryInt(request, 'limit', fallback: 10, min: 1, max: 50);
    final (latDelta, lonDelta) = _degreeDeltas(lat, radius.toDouble());

    final rows = await query(
      deps.db,
      'SELECT * FROM place_view WHERE review_count > 0 '
      'AND latitude BETWEEN @minLat AND @maxLat AND longitude BETWEEN @minLon AND @maxLon '
      'ORDER BY avg_rating DESC, review_count DESC LIMIT @limit:int4',
      {
        'minLat': lat - latDelta,
        'maxLat': lat + latDelta,
        'minLon': lon - lonDelta,
        'maxLon': lon + lonDelta,
        'limit': limit,
      },
    );
    return json(rows.map((r) => placeFromRow(r).toJson()).toList());
  });

  router.get('/places/trending', (Request request) async {
    final days = queryInt(request, 'days', fallback: 7, min: 1, max: 30);
    final limit = queryInt(request, 'limit', fallback: 10, min: 1, max: 50);
    final rows = await query(
      deps.db,
      'SELECT pv.* FROM ('
      '  SELECT place_id, count(*) AS activity FROM ('
      '    SELECT place_id FROM reviews WHERE updated_at > now() - make_interval(days => @days:int4)'
      '    UNION ALL'
      '    SELECT place_id FROM visits WHERE visited_at > now() - make_interval(days => @days:int4)'
      '  ) x GROUP BY place_id ORDER BY activity DESC LIMIT @limit:int4'
      ') a JOIN place_view pv ON pv.id = a.place_id ORDER BY a.activity DESC, pv.name',
      {'days': days, 'limit': limit},
    );
    return json(rows.map((r) => placeFromRow(r).toJson()).toList());
  });

  router.get('/places/<placeId>', (Request request, String placeId) async {
    return json(placeFromRow(await _requirePlace(deps, placeId)).toJson());
  });

  router.get('/places/<placeId>/reviews', (Request request, String placeId) async {
    final rows = await query(
      deps.db,
      '$_reviewSelect WHERE p.google_place_id = @id ORDER BY r.updated_at DESC LIMIT 100',
      {'id': placeId},
    );
    return json(rows.map((r) => reviewFromRow(r).toJson()).toList());
  });

  router.get('/places/<placeId>/summary', (Request request, String placeId) async {
    final place = await queryOne(deps.db, 'SELECT * FROM place_view WHERE google_place_id = @id', {'id': placeId});
    if (place == null) return json(summarize(const [], null).toJson());
    final rows = await query(
      deps.db,
      'SELECT rating, sauce_rating, fleisch_rating, brot_rating, text FROM reviews '
      'WHERE place_id = @id:uuid ORDER BY updated_at DESC',
      {'id': place['id']},
    );
    return json(summarize(rows, place['special_note'] as String?).toJson());
  });

  router.put('/places/<placeId>/review', (Request request, String placeId) async {
    final user = await requireUser(deps, request);
    final body = await readBody(request, UpsertReviewRequest.fromJson);
    for (final value in [body.rating, body.sauceRating, body.fleischRating, body.brotRating]) {
      if (!Validation.isValidRating(value)) throw const ApiException.badRequest('Bewertungen müssen 1–5 sein');
    }
    final text = Validation.clean(body.text);
    final note = Validation.clean(body.specialNote);
    if ((text?.length ?? 0) > Validation.reviewTextMax || (note?.length ?? 0) > Validation.specialNoteMax) {
      throw const ApiException.badRequest('Text zu lang');
    }
    final place = await _requirePlace(deps, placeId);

    final saved = await queryOne(
      deps.db,
      'INSERT INTO reviews (user_id, place_id, rating, sauce_rating, fleisch_rating, brot_rating, text, special_note) '
      'VALUES (@user:uuid, @place:uuid, @rating:int4, @sauce:int4, @fleisch:int4, @brot:int4, @text, @note) '
      'ON CONFLICT (user_id, place_id) DO UPDATE SET rating = EXCLUDED.rating, sauce_rating = EXCLUDED.sauce_rating, '
      'fleisch_rating = EXCLUDED.fleisch_rating, brot_rating = EXCLUDED.brot_rating, text = EXCLUDED.text, '
      'special_note = EXCLUDED.special_note, updated_at = now() RETURNING *',
      {
        'user': user.id,
        'place': place['id'],
        'rating': body.rating,
        'sauce': body.sauceRating,
        'fleisch': body.fleischRating,
        'brot': body.brotRating,
        'text': text,
        'note': note,
      },
    );
    return json(reviewFromRow({
      ...saved!,
      'display_name': user.displayName,
      'google_place_id': placeId,
      'place_name': place['name'],
    }).toJson());
  });

  router.post('/places/<placeId>/visits', (Request request, String placeId) async {
    final user = await requireUser(deps, request);
    final body = await readBody(request, CreateVisitRequest.fromJson);
    final id = requireUuid(body.id);
    final now = DateTime.now().toUtc();
    if (body.visitedAt.isAfter(now.add(const Duration(minutes: 5)))) {
      throw const ApiException.badRequest('Besuch liegt in der Zukunft');
    }
    if (body.foodType != null && FoodItem.byId(body.foodType) == null) {
      throw const ApiException.badRequest('Unbekannter Essenstyp');
    }
    final comment = Validation.clean(body.comment);
    if ((comment?.length ?? 0) > Validation.commentMax) throw const ApiException.badRequest('Kommentar zu lang');
    final place = await _requirePlace(deps, placeId);

    // Client-generated IDs make offline retries idempotent.
    final inserted = await queryOne(
      deps.db,
      'INSERT INTO visits (id, user_id, place_id, visited_at, comment, food_type) '
      'VALUES (@id:uuid, @user:uuid, @place:uuid, @at:timestamptz, @comment, @food) '
      'ON CONFLICT (id) DO NOTHING RETURNING id',
      {'id': id, 'user': user.id, 'place': place['id'], 'at': body.visitedAt, 'comment': comment, 'food': body.foodType},
    );
    if (inserted == null) {
      final existing = await queryOne(deps.db, '$_visitSelect WHERE v.id = @id:uuid', {'id': id});
      if (existing == null || existing['user_id'] != user.id) throw const ApiException.conflict('Besuchs-ID vergeben');
      return json(visitFromRow(existing).toJson());
    }

    // Only a visit that is actually happening now counts as "live" — not
    // one synced hours later from the offline queue.
    final liveUntil = body.visitedAt.toUtc().add(liveStatusDuration);
    if (liveUntil.isAfter(now)) {
      await deps.db.execute(
        Sql.named('UPDATE users SET live_place_id = @place:uuid, live_until = @until:timestamptz, live_food_type = @food '
            'WHERE id = @user:uuid'),
        parameters: {'place': place['id'], 'until': liveUntil, 'food': body.foodType, 'user': user.id},
      );
    }

    final row = await queryOne(deps.db, '$_visitSelect WHERE v.id = @id:uuid', {'id': id});
    return json(visitFromRow(row!).toJson(), status: 201);
  });

  router.get('/me/visits', (Request request) async {
    final user = await requireUser(deps, request);
    final rows = await query(deps.db, '$_visitSelect WHERE v.user_id = @user:uuid ORDER BY v.visited_at DESC', {
      'user': user.id,
    });
    return json(rows.map((r) => visitFromRow(r).toJson()).toList());
  });

  router.get('/me/reviews', (Request request) async {
    final user = await requireUser(deps, request);
    final rows = await query(deps.db, '$_reviewSelect WHERE r.user_id = @user:uuid ORDER BY r.updated_at DESC', {
      'user': user.id,
    });
    return json(rows.map((r) => reviewFromRow(r).toJson()).toList());
  });

  // Places of the user's own visits/reviews — lets a fresh device (or the
  // web app) show history without panning the map first.
  router.get('/me/places', (Request request) async {
    final user = await requireUser(deps, request);
    final rows = await query(
      deps.db,
      'SELECT * FROM place_view WHERE id IN (SELECT place_id FROM visits WHERE user_id = @user:uuid '
      'UNION SELECT place_id FROM reviews WHERE user_id = @user:uuid)',
      {'user': user.id},
    );
    return json(rows.map((r) => placeFromRow(r).toJson()).toList());
  });
}

Future<void> _syncTile(Deps deps, String apiKey, Tile tile) async {
  // Atomically claim the tile so concurrent requests don't both pay Google.
  final claimed = await queryOne(
    deps.db,
    'INSERT INTO search_tiles (tile_key, searched_at) VALUES (@key, now()) '
    'ON CONFLICT (tile_key) DO UPDATE SET searched_at = now() '
    'WHERE search_tiles.searched_at < now() - make_interval(days => @ttl:int4) RETURNING tile_key',
    {'key': tile.key, 'ttl': tileTtl.inDays},
  );
  if (claimed == null) return;

  try {
    final places = await searchTile(deps.httpClient, apiKey, tile);
    for (final p in places.where((p) => p.isOpenBusiness && p.looksLikeDoener)) {
      await _upsertPlace(deps, p);
    }
  } catch (e) {
    print('Tile ${tile.key} sync failed: $e');
    await deps.db.execute(Sql.named('DELETE FROM search_tiles WHERE tile_key = @key'), parameters: {'key': tile.key});
  }
}

Future<void> _upsertPlace(Deps deps, GooglePlace p) => deps.db.execute(
      Sql.named(
        'INSERT INTO places (google_place_id, name, latitude, longitude, address, postal_code, city, opening_hours) '
        'VALUES (@id, @name, @lat, @lon, @address, @postal, @city, @hours) '
        'ON CONFLICT (google_place_id) DO UPDATE SET name = EXCLUDED.name, latitude = EXCLUDED.latitude, '
        'longitude = EXCLUDED.longitude, address = EXCLUDED.address, postal_code = EXCLUDED.postal_code, '
        'city = EXCLUDED.city, opening_hours = EXCLUDED.opening_hours, synced_at = now()',
      ),
      parameters: {
        'id': p.id,
        'name': p.name,
        'lat': p.latitude,
        'lon': p.longitude,
        'address': p.address,
        'postal': p.postalCode,
        'city': p.city,
        'hours': p.openingHours,
      },
    );

/// Keeps the place cache within Google's terms: details may be stored for at
/// most 30 days (only the place ID indefinitely). Places with user activity
/// are refreshed before that; untouched ones are dropped and come back when
/// someone looks at the area again. Runs daily.
Future<void> maintainPlaceCache(Deps deps) async {
  const activity = 'EXISTS (SELECT 1 FROM reviews r WHERE r.place_id = p.id) '
      'OR EXISTS (SELECT 1 FROM visits v WHERE v.place_id = p.id) '
      'OR EXISTS (SELECT 1 FROM users u WHERE u.live_place_id = p.id)';

  final apiKey = deps.config.googlePlacesApiKey;
  if (apiKey != null) {
    final stale = await query(
      deps.db,
      "SELECT google_place_id FROM places p WHERE synced_at < now() - interval '25 days' AND ($activity)",
    );
    for (final row in stale) {
      final id = row['google_place_id'] as String;
      try {
        final place = await fetchPlace(deps.httpClient, apiKey, id);
        if (place != null) await _upsertPlace(deps, place);
      } catch (e) {
        print('Refreshing place $id failed: $e');
      }
    }
  }

  final deleted = await query(
    deps.db,
    "DELETE FROM places p WHERE synced_at < now() - interval '30 days' AND NOT ($activity) RETURNING id",
  );
  if (deleted.isNotEmpty) print('Place cache: dropped ${deleted.length} places older than 30 days');
}

(double, double) _degreeDeltas(double lat, double radiusMeters) {
  const metersPerDegree = 111000.0;
  final cosLat = math.cos(lat * math.pi / 180).abs().clamp(0.01, 1.0);
  return (radiusMeters / metersPerDegree, radiusMeters / (metersPerDegree * cosLat));
}

/// Human-readable community summary (German), built from the place's reviews.
PlaceSummaryDto summarize(List<Map<String, dynamic>> reviews, String? specialNote) {
  if (reviews.isEmpty) return const PlaceSummaryDto(reviewCount: 0, summaryText: 'Noch keine Bewertungen.');

  double? avgOf(String column) {
    final values = reviews.map((r) => r[column] as int?).whereType<int>().toList();
    return values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;
  }

  final count = reviews.length;
  final avg = avgOf('rating')!;
  final dims = {'Soße': avgOf('sauce_rating'), 'Fleisch': avgOf('fleisch_rating'), 'Brot': avgOf('brot_rating')};
  final ranked = dims.entries.where((e) => e.value != null).toList()..sort((a, b) => b.value!.compareTo(a.value!));
  final top = ranked.isEmpty ? null : ranked.first;

  final word = switch (avg.round()) {
    5 => 'ausgezeichnet',
    4 => 'gut',
    3 => 'okay',
    2 => 'mäßig',
    _ => 'schlecht',
  };
  final parts = ['$count ${count == 1 ? 'Bewertung' : 'Bewertungen'}, insgesamt $word (${avg.toStringAsFixed(1)}/5).'];
  if (top != null && top.value! >= 3.5) {
    parts.add('${top.key} wird besonders gelobt (${top.value!.toStringAsFixed(1)}/5).');
  }
  if (specialNote != null) parts.add('Bekannt für: $specialNote.');
  final latestText = reviews.map((r) => r['text'] as String?).whereType<String>().firstOrNull;
  if (latestText != null) {
    final snippet = latestText.length > 80 ? '${latestText.substring(0, 77)}…' : latestText;
    parts.add('„$snippet“');
  }

  return PlaceSummaryDto(
    reviewCount: count,
    avgRating: avg,
    avgSauceRating: dims['Soße'],
    avgFleischRating: dims['Fleisch'],
    avgBrotRating: dims['Brot'],
    topDimension: top?.key,
    summaryText: parts.join(' '),
  );
}
