// LocationHelper — permission-aware, fresh GPS fix for recentering the map
// on the user's exact location. Deliberately avoids last-known positions so
// the map never jumps to a stale location.
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'map_config.dart';

abstract final class LocationHelper {
  /// Returns the current position clamped into the Irbid bounds, or null
  /// when permission is denied or a fresh fix cannot be obtained.
  static Future<LatLng?> locateClamped() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
      timeLimit: const Duration(seconds: 10),
    );
    return MapConfig.clampToBounds(LatLng(pos.latitude, pos.longitude));
  }
}
