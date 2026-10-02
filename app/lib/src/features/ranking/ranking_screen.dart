import 'package:doener_models/doener_models.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/app_data.dart';
import '../../core/location.dart';
import '../../core/maps.dart';
import '../../ui/widgets.dart';
import '../place/place_detail.dart';

/// Moving further than this can mean another city.
const _reloadDistance = 1000.0;

/// The best places of the user's city, overall or by sauce, meat and bread.
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  RatingDimension _by = RatingDimension.overall;
  Future<RankingDto>? _ranking;
  LatLng? _center;

  void _load() {
    final center = _center = context.read<LocationService>().position ?? fallbackLocation;
    _ranking = context.read<AppData>().ranking(center.latitude, center.longitude, _by);
  }

  @override
  Widget build(BuildContext context) {
    final position = context.watch<LocationService>().position;
    final center = _center;
    if (_ranking == null ||
        (position != null &&
            center != null &&
            Geolocator.distanceBetween(center.latitude, center.longitude, position.latitude, position.longitude) >
                _reloadDistance)) {
      _load();
    }

    return FutureBuilder<RankingDto>(
      future: _ranking,
      builder: (context, snapshot) {
        final ranking = snapshot.connectionState == ConnectionState.done ? snapshot.data : null;
        final city = ranking?.city;
        return Scaffold(
          appBar: AppBar(title: Text(city == null ? 'Ranking' : 'Ranking $city')),
          body: RefreshIndicator(
            onRefresh: () async {
              setState(_load);
              await _ranking!.catchError((_) => RankingDto(by: _by, entries: const []));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<RatingDimension>(
                  segments: [for (final d in RatingDimension.values) ButtonSegment(value: d, label: Text(d.label))],
                  selected: {_by},
                  // Four segments on a phone: without the check mark "Gesamt" stays on one line.
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() {
                    _by = s.first;
                    _load();
                  }),
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState != ConnectionState.done)
                  const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                else if (snapshot.hasError)
                  EmptyState(
                    icon: Icons.cloud_off,
                    title: 'Ranking nicht geladen',
                    message: '${snapshot.error}',
                    action: OutlinedButton(onPressed: () => setState(_load), child: const Text('Erneut versuchen')),
                  )
                else if (city == null)
                  const EmptyState(
                    icon: Icons.emoji_events_outlined,
                    title: 'Hier gibt es noch kein Ranking',
                    message: 'Die App kennt in deiner Gegend noch keine Döner-Läden. Schau auf der Karte, was es gibt.',
                  )
                else if (ranking!.entries.isEmpty)
                  EmptyState(
                    icon: Icons.emoji_events_outlined,
                    title: 'Noch keine Bewertungen in $city',
                    message: _by == RatingDimension.overall
                        ? 'Bewerte deinen Stammladen – dann steht er hier ganz oben.'
                        : 'Für ${_by.label} hat hier noch niemand eine Note vergeben.',
                  )
                else
                  for (final (i, entry) in ranking.entries.indexed)
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: _RankingRow(rank: i + 1, entry: entry)),
                const GoogleAttribution(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RankingRow extends StatelessWidget {
  final int rank;
  final RankingEntryDto entry;
  const _RankingRow({required this.rank, required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      onTap: () => showPlaceDetail(context, entry.place),
      child: Row(
        children: [
          RankBadge(rank: rank),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.place.name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (entry.friends.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.group, size: 14, color: doenerOrange),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        entry.friends.map((f) => '${f.user.displayName} ${f.rating}').join(' · '),
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
          Column(children: [
            Text(formatRating(entry.average), style: const TextStyle(color: doenerOrange, fontWeight: FontWeight.bold, fontSize: 20)),
            Text('${entry.count} Bew.', style: theme.textTheme.labelSmall),
          ]),
        ],
      ),
    );
  }
}
