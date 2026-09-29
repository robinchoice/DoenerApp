import 'package:doener_models/doener_models.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_data.dart';
import '../../ui/widgets.dart';

/// Pops `true` when a review was saved.
class ReviewSheet extends StatefulWidget {
  final PlaceDto place;
  const ReviewSheet({super.key, required this.place});

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  late final ReviewDto? _existing = context.read<AppData>().reviews[widget.place.placeId]?.dto;
  late final _text = TextEditingController(text: _existing?.text);
  late final _specialNote = TextEditingController(text: _existing?.specialNote);
  late int _sauce = _existing?.sauceRating ?? 0;
  late int _fleisch = _existing?.fleischRating ?? 0;
  late int _brot = _existing?.brotRating ?? 0;
  late int _manual = _existing?.rating ?? 0;
  // A stored overall rating that differs from the dimension average was set by hand.
  late bool _override = _existing != null && _computed > 0 && _existing.rating != _computed;

  int get _computed {
    final dims = [_sauce, _fleisch, _brot].where((v) => v > 0).toList();
    return dims.isEmpty ? 0 : (dims.reduce((a, b) => a + b) / dims.length).round();
  }

  int get _effective => _override || _computed == 0 ? _manual : _computed;

  @override
  void dispose() {
    _text.dispose();
    _specialNote.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    int? dim(int v) => v > 0 ? v : null;
    await context.read<AppData>().saveReview(
          widget.place,
          UpsertReviewRequest(
            rating: _effective,
            sauceRating: dim(_sauce),
            fleischRating: dim(_fleisch),
            brotRating: dim(_brot),
            text: Validation.clean(_text.text),
            specialNote: Validation.clean(_specialNote.text),
          ),
        );
    if (mounted) Navigator.of(context).pop(true);
  }

  Widget _dimension(String label, int value, ValueChanged<int> onChanged) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 64, child: Text(label)),
            DoenerRating(value: value, size: 28, onChanged: (v) => setState(() => onChanged(v))),
            const Spacer(),
            // Fixed slot so the row height doesn't jump when the clear button appears.
            SizedBox.square(
              dimension: 40,
              child: value > 0
                  ? IconButton(icon: const Icon(Icons.cancel, size: 18), onPressed: () => setState(() => onChanged(0)))
                  : null,
            ),
          ],
        ),
      );

  static const _labels = ['', 'Schlecht', 'Naja', 'Okay', 'Gut', 'Ausgezeichnet'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(_existing == null ? 'Bewerten' : 'Bewertung bearbeiten', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
        Text(widget.place.name, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.outline)),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(children: [
            _dimension('Soße', _sauce, (v) => _sauce = v),
            _dimension('Fleisch', _fleisch, (v) => _fleisch = v),
            _dimension('Brot', _brot, (v) => _brot = v),
          ]),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text('Gesamt', style: theme.textTheme.titleSmall),
            const Spacer(),
            if (_computed > 0)
              TextButton(
                onPressed: () => setState(() {
                  _override = !_override;
                  if (_override) _manual = _computed;
                }),
                child: Text(_override ? 'Automatisch' : 'Manuell'),
              ),
          ],
        ),
        Center(
          child: DoenerRating(
            value: _effective,
            size: 40,
            onChanged: _override || _computed == 0 ? (v) => setState(() => _manual = v) : null,
          ),
        ),
        if (_effective > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_labels[_effective], textAlign: TextAlign.center, style: const TextStyle(color: doenerOrange, fontWeight: FontWeight.w600)),
          ),
        const SizedBox(height: 20),
        TextField(
          controller: _specialNote,
          maxLength: Validation.specialNoteMax,
          decoration: const InputDecoration(hintText: 'Was macht den Laden besonders?'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _text,
          minLines: 3,
          maxLines: 6,
          maxLength: Validation.reviewTextMax,
          decoration: const InputDecoration(hintText: 'Was war gut, was nicht? (optional)'),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _effective == 0 ? null : _save, child: const Text('Speichern')),
      ],
    );
  }
}
