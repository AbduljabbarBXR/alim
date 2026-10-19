import 'package:geolocator/geolocator.dart';

/// A place on the map, kept only for prayer times and the qibla.
class AlimLocation {
  const AlimLocation(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  String toString() =>
      '${latitude.toStringAsFixed(3)}, ${longitude.toStringAsFixed(3)}';
}

/// Asks for a fix once, quietly: low accuracy is plenty for prayer times and
/// the qibla, and nothing here ever runs in the background.
class LocationService {
  LocationService._();

  static Future<AlimLocation?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return AlimLocation(position.latitude, position.longitude);
    } catch (_) {
      // A timeout or a tired GPS falls back to the last known fix.
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return AlimLocation(last.latitude, last.longitude);
      } catch (_) {}
      return null;
    }
  }
}
