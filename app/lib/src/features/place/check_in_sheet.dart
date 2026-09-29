import 'dart:math' as math;

import 'package:doener_models/doener_models.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_data.dart';
import '../../ui/widgets.dart';

class CheckInSheet extends StatefulWidget {
  final PlaceDto place;
  const CheckInSheet({super.key, required this.place});

  @override
  State<CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<CheckInSheet> {
  final _comment = TextEditingController();
  int _selected = 0;
  bool _done = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _checkIn() async {
    setState(() => _done = true);
    await context.read<AppData>().checkIn(
          widget.place,
          foodType: FoodItem.all[_selected].id,
          comment: _comment.text,
        );
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text('Einchecken', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            Text(widget.place.name, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 8),
            RotaryPicker(selected: _selected, onChanged: (i) => setState(() => _selected = i)),
            Center(
              child: SizedBox.square(
                dimension: 72,
                child: FilledButton(
                  style: FilledButton.styleFrom(shape: const CircleBorder(), backgroundColor: doenerOrange, padding: EdgeInsets.zero),
                  onPressed: _done ? null : _checkIn,
                  child: const Icon(Icons.check, size: 34, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _comment,
              maxLength: Validation.commentMax,
              decoration: const InputDecoration(hintText: 'Kommentar (optional)'),
            ),
          ],
        ),
        if (_done) Positioned.fill(child: IgnorePointer(child: Confetti(emoji: FoodItem.all[_selected].emoji))),
      ],
    );
  }
}

/// Food wheel: drag sideways or tap an item to rotate it to the top.
class RotaryPicker extends StatefulWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const RotaryPicker({super.key, required this.selected, required this.onChanged});

  @override
  State<RotaryPicker> createState() => _RotaryPickerState();
}

class _RotaryPickerState extends State<RotaryPicker> {
  static const _radius = 100.0;
  double _drag = 0;

  double get _step => 360 / FoodItem.all.length;

  void _settle() {
    final steps = (-_drag / _step).round();
    final count = FoodItem.all.length;
    widget.onChanged(((widget.selected + steps) % count + count) % count);
    setState(() => _drag = 0);
  }

  @override
  Widget build(BuildContext context) {
    final items = FoodItem.all;
    return GestureDetector(
      onHorizontalDragUpdate: (d) => setState(() => _drag += d.delta.dx * 0.5),
      onHorizontalDragEnd: (_) => _settle(),
      child: SizedBox(
        height: _radius * 2 + 90,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < items.length; i++)
              Builder(builder: (context) {
                final angle = (i - widget.selected) * _step + _drag;
                final normalized = (((angle % 360) + 540) % 360 - 180).abs() / 180; // 0 at top, 1 at bottom
                final radians = angle * math.pi / 180;
                return AnimatedSlide(
                  duration: _drag == 0 ? const Duration(milliseconds: 300) : Duration.zero,
                  curve: Curves.easeOutBack,
                  offset: Offset(math.sin(radians) * _radius / 60, -math.cos(radians) * _radius / 60),
                  child: GestureDetector(
                    onTap: () => widget.onChanged(i),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: Center(
                        child: Opacity(
                          opacity: 1 - normalized * 0.5,
                          child: Text(items[i].emoji, style: TextStyle(fontSize: 44 * (1.3 - normalized * 0.7))),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                items[widget.selected].label,
                key: ValueKey(widget.selected),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Emoji rain after a check-in.
class Confetti extends StatefulWidget {
  final String emoji;
  const Confetti({super.key, required this.emoji});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();
  final _random = math.Random();
  late final _particles = List.generate(
    20,
    (_) => (x: _random.nextDouble(), size: 20 + _random.nextDouble() * 20, delay: _random.nextDouble() * 0.2, rotation: _random.nextDouble() - 0.5),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Stack(
            children: [
              for (final p in _particles)
                Positioned(
                  left: p.x * (constraints.maxWidth - p.size),
                  top: -50 + Curves.easeIn.transform(((_controller.value - p.delay) / (1 - p.delay)).clamp(0, 1)) * (constraints.maxHeight + 100),
                  child: Transform.rotate(angle: p.rotation, child: Text(widget.emoji, style: TextStyle(fontSize: p.size))),
                ),
            ],
          ),
        ),
      );
}
