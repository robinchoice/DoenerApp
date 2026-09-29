import 'package:doener_models/doener_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_data.dart';
import '../../core/session.dart';
import '../../ui/widgets.dart';
import '../auth/login_screen.dart';
import '../settings/settings_screen.dart';
import '../social/friends.dart';

List<(FoodItem, int)> foodCounts(Iterable<VisitDto> visits) {
  final counts = <String, int>{};
  for (final v in visits) {
    if (v.foodType != null) counts[v.foodType!] = (counts[v.foodType!] ?? 0) + 1;
  }
  return [for (final f in FoodItem.all) if (counts[f.id] case final n?) (f, n)]..sort((a, b) => b.$2.compareTo(a.$2));
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _friendsLoadedFor;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final data = context.watch<AppData>();
    final friends = context.watch<Friends>();
    final user = session.user;

    if (user?.id != _friendsLoadedFor) {
      _friendsLoadedFor = user?.id;
      WidgetsBinding.instance.addPostFrameCallback((_) => friends.load());
    }

    final visits = data.visits.map((v) => v.dto).toList();
    final stats = ProfileStats.compute(visits: visits, reviewCount: data.reviews.length, cityOf: (id) => data.places[id]?.city);
    final foods = foodCounts(visits);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            tooltip: 'Einstellungen',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (session.expired)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MaterialBanner(
                content: const Text('Deine Sitzung ist abgelaufen. Ungesendete Einträge bleiben gespeichert.'),
                actions: [TextButton(onPressed: () => showLogin(context), child: const Text('Anmelden'))],
              ),
            ),
          GlassCard(
            child: Row(
              children: [
                ClipOval(child: Image.asset('assets/logo.jpg', width: 64, height: 64, fit: BoxFit.cover)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.displayName ?? 'Döner-Fan', style: Theme.of(context).textTheme.titleLarge),
                      if (stats.firstVisit != null)
                        Text('Seit ${DateFormat('MMMM y', 'de').format(stats.firstVisit!.toLocal())}',
                            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                ),
                if (user == null) FilledButton(onPressed: () => showLogin(context), child: const Text('Anmelden')),
              ],
            ),
          ),
          if (user != null) ...[
            const SizedBox(height: 12),
            GlassCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FriendsScreen())),
              child: Row(children: [
                const Icon(Icons.group, color: doenerOrange),
                const SizedBox(width: 12),
                const Expanded(child: Text('Freunde')),
                if (friends.incoming.isNotEmpty) Badge(label: Text('${friends.incoming.length}')),
                const SizedBox(width: 8),
                Text('${friends.accepted.length}'),
                const Icon(Icons.chevron_right),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          Row(children: [
            _StatCard(value: stats.totalVisits, label: 'Besuche', icon: Icons.check_circle, color: Colors.green),
            const SizedBox(width: 12),
            _StatCard(value: stats.totalReviews, label: 'Bewertungen', icon: Icons.star, color: doenerOrange),
            const SizedBox(width: 12),
            _StatCard(value: stats.uniquePlaces, label: 'Läden', icon: Icons.place, color: Colors.purple),
          ]),
          const SizedBox(height: 12),
          FoodStatsCard(foods: foods),
          const SizedBox(height: 12),
          GlassCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const WrappedScreen())),
            child: Row(children: [
              const Icon(Icons.auto_awesome, color: doenerOrange, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Döner Wrapped ${DateTime.now().year}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Dein persönlicher Jahresrückblick', style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
          const SizedBox(height: 12),
          _StampCard(stats: stats),
          const SizedBox(height: 20),
          _Achievements(unlocked: stats.unlockedAchievements(friendsCount: friends.accepted.length)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final Color color;
  const _StatCard({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GlassCard(
          child: Column(children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text('$value', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ]),
        ),
      );
}

class FoodStatsCard extends StatelessWidget {
  final List<(FoodItem, int)> foods;
  const FoodStatsCard({super.key, required this.foods});

  @override
  Widget build(BuildContext context) => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(icon: Icons.bar_chart, title: 'Dein Döner-Konsum'),
            if (foods.isEmpty) Text('Noch keine Check-ins mit Essenstyp', style: Theme.of(context).textTheme.bodySmall),
            for (final (food, count) in foods)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(width: 32, child: Text(food.emoji, style: const TextStyle(fontSize: 20))),
                  SizedBox(width: 80, child: Text(food.label)),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) => Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: c.maxWidth * count / foods.first.$2,
                          height: 20,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(color: doenerOrange, borderRadius: BorderRadius.circular(10)),
                          child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
          ],
        ),
      );
}

class _StampCard extends StatelessWidget {
  final ProfileStats stats;
  const _StampCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final tier = stats.stampTier;
    final color = tierColor(tier);
    final next = tier.nextTier;
    final inTier = stats.totalVisits - tier.stampsRequired;
    final dots = next == null ? 10 : next.stampsRequired - tier.stampsRequired;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: Icons.verified,
            title: 'Stempelkarte',
            trailing: Chip(
              label: Text(tier.displayName, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              backgroundColor: color.withValues(alpha: 0.15),
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: stats.stampProgress, minHeight: 8, color: color, backgroundColor: color.withValues(alpha: 0.15)),
          ),
          const SizedBox(height: 6),
          Text(
            next == null ? 'Höchste Stufe erreicht!' : 'Noch ${stats.stampsToNextTier} Besuche bis ${next.displayName}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < dots; i++)
                CircleAvatar(
                  radius: 8,
                  backgroundColor: i < inTier || next == null ? color : Colors.grey.withValues(alpha: 0.2),
                  child: i < inTier || next == null ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Achievements extends StatelessWidget {
  final Set<AchievementType> unlocked;
  const _Achievements({required this.unlocked});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: Icons.emoji_events,
            title: 'Erfolge',
            trailing: Text('${unlocked.length}/${AchievementType.values.length}'),
          ),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.8,
            children: [
              for (final type in AchievementType.values)
                Tooltip(
                  message: type.description,
                  triggerMode: TooltipTriggerMode.tap,
                  child: Column(children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: unlocked.contains(type) ? doenerOrange.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.08),
                      child: Icon(achievementIcon(type), color: unlocked.contains(type) ? doenerOrange : Colors.grey.withValues(alpha: 0.4)),
                    ),
                    const SizedBox(height: 4),
                    Text(type.title, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 10)),
                  ]),
                ),
            ],
          ),
        ],
      );
}

/// Yearly recap in five swipeable pages.
class WrappedScreen extends StatefulWidget {
  const WrappedScreen({super.key});

  @override
  State<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends State<WrappedScreen> {
  int _page = 0;

  static const _gradients = [
    [Colors.orange, Colors.red],
    [Colors.pink, Colors.purple],
    [Colors.blue, Colors.cyan],
    [Colors.green, Colors.teal],
    [Colors.orange, Colors.amber],
  ];

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final year = DateTime.now().year;
    final visits = data.visits.map((v) => v.dto).where((v) => v.visitedAt.toLocal().year == year).toList();
    final reviewCount = data.reviews.values.where((r) => r.dto.createdAt.toLocal().year == year).length;
    final foods = foodCounts(visits);
    final byPlace = <String, List<VisitDto>>{};
    final byMonth = <int, int>{};
    for (final v in visits) {
      byPlace.putIfAbsent(v.placeId, () => []).add(v);
      final m = v.visitedAt.toLocal().month;
      byMonth[m] = (byMonth[m] ?? 0) + 1;
    }
    final topPlace = byPlace.values.fold<List<VisitDto>?>(null, (best, v) => best == null || v.length > best.length ? v : best);
    final busiestMonth = byMonth.entries.fold<MapEntry<int, int>?>(null, (best, e) => best == null || e.value > best.value ? e : best);
    final monthName = busiestMonth == null ? null : DateFormat('MMMM', 'de').format(DateTime(year, busiestMonth.key));

    const white = TextStyle(color: Colors.white);
    Widget big(String text) => Text(text, style: white.copyWith(fontSize: 64, fontWeight: FontWeight.bold), textAlign: TextAlign.center);
    Widget label(String text) => Text(text, style: white.copyWith(fontSize: 20), textAlign: TextAlign.center);
    Widget emoji(String e) => Text(e, style: const TextStyle(fontSize: 80));

    final pages = [
      [emoji('🥙'), big('${visits.length}'), label('Döner-Besuche in $year')],
      if (foods.isNotEmpty)
        [emoji(foods.first.$1.emoji), label('Dein Favorit:'), big(foods.first.$1.label), label('${foods.first.$2}×')]
      else
        [emoji('🤷'), label('Noch kein Lieblings-Essen')],
      [emoji('📍'), if (topPlace != null) ...[label('Dein Stammladen:'), big(topPlace.first.placeName), label('${topPlace.length} Besuche')] else label('Noch kein Stammladen')],
      [emoji('🗺️'), big('${byPlace.length}'), label('verschiedene Läden entdeckt')],
      [
        emoji('🏆'),
        label('Dein $year'),
        const SizedBox(height: 16),
        label('🥙 ${visits.length} Besuche'),
        label('⭐ $reviewCount Bewertungen'),
        label('📍 ${byPlace.length} Läden'),
        if (foods.isNotEmpty) label('${foods.first.$1.emoji} ${foods.first.$2}× ${foods.first.$1.label}'),
        if (monthName != null) label('📅 Aktivster Monat: $monthName'),
      ],
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(gradient: LinearGradient(colors: _gradients[_page], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Stack(
          children: [
            PageView(
              onPageChanged: (p) => setState(() => _page = p),
              children: [
                for (final children in pages)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: FittedBox(fit: BoxFit.scaleDown, child: Column(mainAxisSize: MainAxisSize.min, children: children)),
                    ),
                  ),
              ],
            ),
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    Container(
                      margin: const EdgeInsets.all(4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: i == _page ? 1 : 0.4)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
