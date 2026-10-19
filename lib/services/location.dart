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

    if (!await Geolocator.isLocationServiceEnabled()) {
      await _askToTurnOnLocation();
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationProblemException(LocationProblem.serviceOff);
      }
    }

    try {
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
      throw const LocationProblemException(LocationProblem.unavailable);
    }
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
