import 'package:doener_models/doener_models.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_data.dart';
import '../../core/location.dart';
import '../../ui/widgets.dart';
import '../feed/feed_screen.dart';
import '../place/place_detail.dart';

class DiscoverScreen extends StatefulWidget {
  final VoidCallback onOpenMap;
  const DiscoverScreen({super.key, required this.onOpenMap});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _search = TextEditingController();
  List<PlaceDto> _nearby = [];
  List<PlaceDto> _trending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final data = context.read<AppData>();
    final center = context.read<LocationService>().position ?? fallbackLocation;
    setState(() => _loading = true);
    final results = await Future.wait([
      data.topNearby(center.latitude, center.longitude).catchError((_) => _nearby),
      data.trending().catchError((_) => _trending),
    ]);
    if (!mounted) return;
    setState(() {
      _nearby = results[0];
      _trending = results[1];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final query = _search.text.trim();
    final recentReviews = data.reviews.values.toList()..sort((a, b) => b.dto.updatedAt.compareTo(a.dto.updatedAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entdecken'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Döner-Laden suchen…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(_search.clear)),
              ),
            ),
          ),
        ),
      ),
      body: query.isNotEmpty
          ? _SearchResults(
              places: data.places.values.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).toList()
                ..sort((a, b) => a.name.compareTo(b.name)),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_loading && _nearby.isEmpty && _trending.isEmpty)
                    const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
                  if (_nearby.isNotEmpty) _PlaceCarousel(icon: Icons.near_me, title: 'In deiner Nähe', places: _nearby),
                  if (_trending.isNotEmpty) _PlaceCarousel(icon: Icons.local_fire_department, title: 'Gerade im Hype', places: _trending),
                  if (recentReviews.isNotEmpty) ...[
                    const SectionTitle(icon: Icons.rate_review, title: 'Neu bewertet'),
                    for (final r in recentReviews.take(10))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ActivityCard(
                          type: FeedItemType.review,
                          title: 'Bewertet',
                          subtitle: r.dto.placeName,
                          timestamp: r.dto.updatedAt,
                          rating: r.dto.rating,
                          text: r.dto.text,
                          pending: r.pending,
                          onTap: data.places[r.dto.placeId] == null ? null : () => showPlaceDetail(context, data.places[r.dto.placeId]!),
                        ),
                      ),
                  ],
                  if (!_loading && _nearby.isEmpty && _trending.isEmpty && recentReviews.isEmpty)
                    EmptyState(
                      icon: Icons.restaurant,
                      title: 'Noch keine Empfehlungen',
                      message: 'Checke bei Döner-Läden ein und bewerte sie, um Empfehlungen zu sehen.',
                      action: FilledButton(onPressed: widget.onOpenMap, child: const Text('Döner-Laden finden')),
                    ),
                ],
              ),
            ),
    );
  }
}

class _PlaceCarousel extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<PlaceDto> places;
  const _PlaceCarousel({required this.icon, required this.title, required this.places});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(icon: icon, title: title),
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: places.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => SizedBox(width: 170, child: _PlaceCard(place: places[i])),
              ),
            ),
          ],
        ),
      );
}

class _PlaceCard extends StatelessWidget {
  final PlaceDto place;
  const _PlaceCard({required this.place});

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.all(12),
        onTap: () => showPlaceDetail(context, place),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (place.city != null) Text(place.city!, style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            if (place.avgRating != null)
              Row(children: [
                DoenerRating(value: place.avgRating!.round(), size: 12),
                const SizedBox(width: 4),
                Text(formatRating(place.avgRating!), style: const TextStyle(color: doenerOrange, fontWeight: FontWeight.bold, fontSize: 12)),
                Text(' (${place.reviewCount})', style: Theme.of(context).textTheme.labelSmall),
              ]),
            if (place.specialNote != null)
              Text(place.specialNote!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: doenerOrange, fontSize: 11)),
          ],
        ),
      );
}

class _SearchResults extends StatelessWidget {
  final List<PlaceDto> places;
  const _SearchResults({required this.places});

  @override
  Widget build(BuildContext context) {
    if (places.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'Nichts gefunden',
        message: 'Gesucht wird in allen Läden, die du auf der Karte schon gesehen hast.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: places.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final p = places[i];
        return GlassCard(
          onTap: () => showPlaceDetail(context, p),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (p.city != null) Text(p.city!, style: Theme.of(context).textTheme.bodySmall),
                    if (p.specialNote != null) Text(p.specialNote!, style: const TextStyle(color: doenerOrange, fontSize: 12)),
                  ],
                ),
              ),
              if (p.avgRating != null)
                Column(children: [
                  Text(formatRating(p.avgRating!), style: const TextStyle(color: doenerOrange, fontWeight: FontWeight.bold, fontSize: 20)),
                  Text('${p.reviewCount} Bew.', style: Theme.of(context).textTheme.labelSmall),
                ]),
            ],
          ),
        );
      },
    );
  }
}
