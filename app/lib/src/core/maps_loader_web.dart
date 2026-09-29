import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Injects the Maps JavaScript API before the first GoogleMap widget is built,
/// so the key comes from the build instead of a hard-coded index.html.
Future<void> loadGoogleMapsScript(String key) {
  if (key.isEmpty) return Future.value();
  final loaded = Completer<void>();
  final script = web.HTMLScriptElement()
    ..src = 'https://maps.googleapis.com/maps/api/js?key=${Uri.encodeQueryComponent(key)}'
    ..async = true;
  script.addEventListener('load', ((web.Event _) => loaded.complete()).toJS);
  script.addEventListener('error', ((web.Event _) => loaded.complete()).toJS);
  web.document.head!.append(script);
  return loaded.future;
}
