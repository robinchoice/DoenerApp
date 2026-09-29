import 'package:doener_models/doener_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const doenerOrange = Color(0xFFFF8C00);

ThemeData buildTheme(Brightness brightness) {
  // Buttons in the brand orange (as in the iOS app) instead of the muted seed tone.
  final scheme = ColorScheme.fromSeed(seedColor: doenerOrange, brightness: brightness)
      .copyWith(primary: doenerOrange, onPrimary: Colors.white);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ),
  );
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

/// 1–5 rating shown as fork-and-knife icons.
class DoenerRating extends StatelessWidget {
  final int value;
  final double size;
  final ValueChanged<int>? onChanged;
  const DoenerRating({super.key, required this.value, this.size = 16, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final inactive = Theme.of(context).colorScheme.outlineVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(i),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.08),
              child: AnimatedScale(
                scale: onChanged != null && i == value ? 1.12 : 1,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  i <= value ? Icons.restaurant : Icons.restaurant_outlined,
                  size: size,
                  color: i <= value ? doenerOrange : inactive,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class DimensionChip extends StatelessWidget {
  final String label;
  final int value;
  const DimensionChip({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(width: 3),
          DoenerRating(value: value, size: 11),
        ],
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline), textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  const SectionTitle({super.key, required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: doenerOrange),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
            ?trailing,
          ],
        ),
      );
}

class Pill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const Pill({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        elevation: 3,
        shape: const StadiumBorder(),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), child: child),
        ),
      );
}

String formatRating(double value) => value.toStringAsFixed(1).replaceAll('.', ',');

String formatDate(DateTime date) => DateFormat('d. MMM y', 'de').format(date.toLocal());

String formatDateTime(DateTime date) => DateFormat('d. MMM y, HH:mm', 'de').format(date.toLocal());

String relativeTime(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'gerade eben';
  if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
  if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
  if (diff.inDays == 1) return 'gestern';
  if (diff.inDays < 7) return 'vor ${diff.inDays} Tagen';
  return formatDate(date);
}

String foodEmoji(String? foodType) => FoodItem.byId(foodType)?.emoji ?? '✅';

IconData achievementIcon(AchievementType type) => switch (type) {
      AchievementType.firstBite => Icons.restaurant,
      AchievementType.critic => Icons.rate_review,
      AchievementType.regular => Icons.repeat,
      AchievementType.explorer => Icons.map,
      AchievementType.connoisseur => Icons.workspace_premium,
      AchievementType.berlinTour || AchievementType.hamburgTour => Icons.location_city,
      AchievementType.stampCollectorSilver => Icons.verified_outlined,
      AchievementType.stampCollectorGold => Icons.verified,
      AchievementType.nightOwl => Icons.nightlight_round,
      AchievementType.socialButterfly => Icons.groups,
    };

Color tierColor(StampTier tier) => switch (tier) {
      StampTier.doenerneuling => Colors.grey,
      StampTier.doenerfreund => Colors.brown,
      StampTier.doenerfan => doenerOrange,
      StampTier.doenerprofi => Colors.red,
      StampTier.doenermeister => Colors.purple,
      StampTier.doenerlegende => Colors.amber,
    };

void showMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

/// Consistent modal sheet used for all forms.
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: builder(context),
      ),
    );
