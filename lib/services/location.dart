import 'dart:io';

import 'package:flutter/services.dart';
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

/// Why a fix could not be had, so the screen can say the right thing.
enum LocationProblem { serviceOff, blocked, denied, unavailable }

class LocationProblemException implements Exception {
  const LocationProblemException(this.problem);

  final LocationProblem problem;
}

/// Asks for a fix once, quietly: low accuracy is plenty for prayer times and
/// the qibla, and nothing here ever runs in the background.
class LocationService {
  LocationService._();

  static const _channel = MethodChannel('com.alim.app/location');

  /// The permission dialog comes first, so Android can offer precise or
  /// approximate. Only then does the system ask to switch location on.
  static Future<AlimLocation> current() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationProblemException(LocationProblem.blocked);
    }
    if (permission == LocationPermission.denied) {
      throw const LocationProblemException(LocationProblem.denied);
    }

    if (!await _serviceOn(tries: 3)) {
      await _askToTurnOnLocation();
      if (!await _serviceOn(tries: 10)) {
        throw const LocationProblemException(LocationProblem.serviceOff);
      }
    }

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null &&
          DateTime.now().difference(last.timestamp).abs() <
              const Duration(minutes: 30)) {
        return AlimLocation(last.latitude, last.longitude);
      }
    } catch (_) {}

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return AlimLocation(position.latitude, position.longitude);
    } catch (_) {
      // A timeout or a tired GPS falls back to the last known fix.
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return AlimLocation(last.latitude, last.longitude);
      } catch (_) {}
      throw const LocationProblemException(LocationProblem.unavailable);
    }
  }

  static Future<bool> _serviceOn({required int tries}) async {
    for (var i = 0; i < tries; i++) {
      if (await Geolocator.isLocationServiceEnabled()) return true;
      if (i + 1 < tries) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    return false;
  }

  /// Opens Android's own "turn on location" dialog, then waits for the person
  /// to answer. On other platforms the settings screen is the fallback.
  static Future<void> _askToTurnOnLocation() async {
    if (Platform.isAndroid) {
      try {
        await _channel
            .invokeMethod<bool>('turnOn')
            .timeout(const Duration(seconds: 90));
      } catch (_) {}
      return;
    }
    try {
      await Geolocator.openLocationSettings();
    } catch (_) {}
  }
}
