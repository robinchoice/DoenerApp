import 'package:doener_models/doener_models.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_data.dart';
import '../../core/session.dart';
import '../../ui/widgets.dart';
import '../place/place_detail.dart';
import '../social/invite.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  bool _friends = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Freunde')),
                ButtonSegment(value: false, label: Text('Meine')),
              ],
              selected: {_friends},
              onSelectionChanged: (s) => setState(() => _friends = s.first),
            ),
          ),
        ),
      ),
      body: _friends ? const _FriendsFeed() : const _MyFeed(),
    );
  }
}

class _FriendsFeed extends StatefulWidget {
  const _FriendsFeed();

  @override
  State<_FriendsFeed> createState() => _FriendsFeedState();
}

class _FriendsFeedState extends State<_FriendsFeed> {
  final _items = <FeedItem>[];
  List<LiveStatusDto> _live = [];
  String? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  String? _loadedFor;

  Future<void> _refresh() async {
    _items.clear();
    _cursor = null;
    _hasMore = true;
    await Future.wait([_loadMore(), _loadLive()]);
  }

  Future<void> _loadLive() async {
    try {
      final json = await context.read<Session>().api.get('/feed/live') as List;
      if (mounted) setState(() => _live = [for (final l in json) LiveStatusDto.fromJson(l as Map<String, dynamic>)]);
    } catch (_) {
      // Live status is a nice-to-have.
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await context.read<Session>().api.get('/feed', query: {'limit': '20', 'cursor': ?_cursor});
      final page = FeedPage.fromJson(json as Map<String, dynamic>);
      _items.addAll(page.items);
      _cursor = page.cursor;
      _hasMore = page.hasMore;
    } on ApiException catch (e) {
      _error = e.message;
    } on OfflineException catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (_loadedFor != session.user!.id) {
      _loadedFor = session.user!.id;
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }

    if (_items.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty && _error != null) {
      return EmptyState(
        icon: Icons.cloud_off,
        title: 'Feed nicht geladen',
        message: _error!,
        action: OutlinedButton(onPressed: _refresh, child: const Text('Erneut versuchen')),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: _items.isEmpty && _live.isEmpty
          ? ListView(children: [
              const SizedBox(height: 80),
              EmptyState(
                icon: Icons.group,
                title: 'Keine Aktivität',
                message: 'Lade Freunde ein, um zu sehen, wo sie Döner essen.',
                action: FilledButton(
                  onPressed: () => showAppSheet(context, (_) => const InviteSheet()),
                  child: const Text('Freunde einladen'),
                ),
              ),
            ])
          : NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.extentAfter < 400) _loadMore();
                return false;
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_live.isNotEmpty) ...[
                    SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _live.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, i) => SizedBox(width: 170, child: _LiveChip(status: _live[i])),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  for (final item in _items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ActivityCard(
                        type: item.type,
                        title: item.user.displayName,
                        subtitle: '${item.type == FeedItemType.visit ? 'Eingecheckt bei' : 'Bewertet:'} ${item.place.name}',
                        timestamp: item.timestamp,
                        rating: item.rating,
                        text: item.text,
                        foodType: item.foodType,
                        onTap: () => showPlaceDetail(context, item.place),
                      ),
                    ),
                  if (_loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
                ],
              ),
            ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  final LiveStatusDto status;
  const _LiveChip({required this.status});

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status.user.displayName, style: const TextStyle(fontWeight: FontWeight.w600, color: doenerOrange)),
            Text('isst gerade bei ${status.placeName}', maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            if (FoodItem.byId(status.foodType) case final food?) Text('${food.emoji} ${food.label}', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}

class _MyFeed extends StatelessWidget {
  const _MyFeed();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final entries = [
      for (final v in data.visits) (type: FeedItemType.visit, placeId: v.dto.placeId, placeName: v.dto.placeName, at: v.dto.visitedAt, text: v.dto.comment, rating: null as int?, food: v.dto.foodType, pending: v.pending),
      for (final r in data.reviews.values)
        (type: FeedItemType.review, placeId: r.dto.placeId, placeName: r.dto.placeName, at: r.dto.updatedAt, text: r.dto.text, rating: r.dto.rating, food: null as String?, pending: r.pending),
    ]..sort((a, b) => b.at.compareTo(a.at));

    if (entries.isEmpty) {
      return const EmptyState(
        icon: Icons.restaurant,
        title: 'Noch keine Aktivität',
        message: 'Checke bei einem Döner-Laden ein oder schreibe eine Bewertung.',
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await data.sync();
        await data.refreshMine();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ActivityCard(
                type: e.type,
                title: e.type == FeedItemType.visit ? 'Eingecheckt' : 'Bewertet',
                subtitle: e.placeName,
                timestamp: e.at,
                rating: e.rating,
                text: e.text,
                foodType: e.food,
                pending: e.pending,
                onTap: data.places[e.placeId] == null ? null : () => showPlaceDetail(context, data.places[e.placeId]!),
              ),
            ),
        ],
      ),
    );
  }
}

class ActivityCard extends StatelessWidget {
  final FeedItemType type;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final int? rating;
  final String? text;
  final String? foodType;
  final bool pending;
  final VoidCallback? onTap;

  const ActivityCard({
    super.key,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.rating,
    this.text,
    this.foodType,
    this.pending = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVisit = type == FeedItemType.visit;
    final color = isVisit ? Colors.green : doenerOrange;
    return GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.12),
                child: isVisit && foodType != null
                    ? Text(foodEmoji(foodType), style: const TextStyle(fontSize: 18))
                    : Icon(isVisit ? Icons.check_circle : Icons.restaurant, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(subtitle, style: const TextStyle(color: doenerOrange)),
                  ],
                ),
              ),
              if (pending) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.cloud_upload_outlined, size: 16)),
              Text(relativeTime(timestamp), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
          if (rating != null) ...[const SizedBox(height: 8), DoenerRating(value: rating!, size: 14)],
          if (text != null && text!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(text!, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}
