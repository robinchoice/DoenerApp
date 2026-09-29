import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_data.dart';
import '../../ui/widgets.dart';
import '../place/place_detail.dart';

enum _Sort { rating, visits, recent }

/// Personal ranking of places the user visited or reviewed.
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  _Sort _sort = _Sort.rating;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final ids = {...data.visits.map((v) => v.dto.placeId), ...data.reviews.keys};
    final ranked = [
      for (final id in ids)
        if (data.places[id] case final place?)
          (
            place: place,
            visits: data.visitsAt(id),
            rating: data.reviews[id]?.dto.rating,
          ),
    ];
    switch (_sort) {
      case _Sort.rating:
        ranked.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      case _Sort.visits:
        ranked.sort((a, b) => b.visits.length.compareTo(a.visits.length));
      case _Sort.recent:
        DateTime last(List<LocalVisit> v) => v.isEmpty ? DateTime(0) : v.first.dto.visitedAt;
        ranked.sort((a, b) => last(b.visits).compareTo(last(a.visits)));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ranking')),
      body: ranked.isEmpty
          ? const EmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'Noch kein Ranking',
              message: 'Besuche und bewerte Döner-Läden, um dein persönliches Ranking zu erstellen.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<_Sort>(
                  segments: const [
                    ButtonSegment(value: _Sort.rating, label: Text('Bewertung')),
                    ButtonSegment(value: _Sort.visits, label: Text('Besuche')),
                    ButtonSegment(value: _Sort.recent, label: Text('Zuletzt')),
                  ],
                  selected: {_sort},
                  onSelectionChanged: (s) => setState(() => _sort = s.first),
                ),
                const SizedBox(height: 16),
                for (final (index, r) in ranked.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      onTap: () => showPlaceDetail(context, r.place),
                      child: Row(
                        children: [
                          _RankBadge(rank: index + 1),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.place.name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Row(children: [
                                  if (r.visits.isNotEmpty) ...[
                                    const Icon(Icons.check_circle, size: 14, color: Colors.green),
                                    Text(' ${r.visits.length}   '),
                                  ],
                                  if (r.rating != null) DoenerRating(value: r.rating!, size: 12),
                                ]),
                              ],
                            ),
                          ),
                          if (r.place.city != null)
                            Text(r.place.city!, style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final color = switch (rank) { 1 => doenerOrange, 2 => Colors.grey, 3 => Colors.brown, _ => Colors.transparent };
    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withValues(alpha: 0.15),
      child: rank <= 3
          ? Icon(Icons.emoji_events, size: 18, color: color)
          : Text('$rank', style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
