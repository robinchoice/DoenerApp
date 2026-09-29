import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Freiburg — used until (or unless) the user shares their location.
const fallbackLocation = LatLng(47.999, 7.842);

class LocationService extends ChangeNotifier {
  LatLng? position;
  bool denied = false;

  Future<void> request() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      denied = permission == LocationPermission.denied || permission == LocationPermission.deniedForever;
      if (!denied) {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)),
        );
        position = LatLng(p.latitude, p.longitude);
      }
    } catch (e) {
      // Location services off, timeout, or unsupported browser.
      debugPrint('Location unavailable: $e');
    }
    notifyListeners();
  }
}
