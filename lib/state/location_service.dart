import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Best-effort GPS access.
///
/// The app must stay usable when location is denied or unavailable (desktop
/// without Wi-Fi positioning), so every failure returns `null` and the UI falls
/// back to the area chosen by the user.
class LocationService {
  static Position? _last;

  static Future<LatLng?> currentPosition({Duration timeout = const Duration(seconds: 12)}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeout,
        ),
      );
      _last = position;
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('LocationService: $e');
      final last = _last;
      if (last != null) return LatLng(last.latitude, last.longitude);
      return null;
    }
  }

  static Future<bool> isPermanentlyDenied() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.deniedForever;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> ensureServiceEnabled() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (enabled) return true;
    } catch (_) {
      return false;
    }
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}
