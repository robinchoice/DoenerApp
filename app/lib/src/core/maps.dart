import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

export 'maps_loader_stub.dart' if (dart.library.js_interop) 'maps_loader_web.dart';

/// Maps JavaScript API key for the web build (`--dart-define=GOOGLE_MAPS_WEB_KEY=…`).
/// iOS and Android get their keys from the native project configuration.
const mapsWebKey = String.fromEnvironment('GOOGLE_MAPS_WEB_KEY');

bool get mapsAvailable => !kIsWeb || mapsWebKey.isNotEmpty;

/// Hides shops and other businesses so only our pins stand out.
const mapStyle = '[{"featureType":"poi.business","stylers":[{"visibility":"off"}]}]';

/// Google requires attribution wherever Places data is shown without a Google map.
class GoogleAttribution extends StatelessWidget {
  const GoogleAttribution({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Ortsdaten: Google Maps',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
      );
}
