import 'package:geolocator/geolocator.dart';
import 'dart:developer' as developer;

class LocationService {
  Future<bool> ensurePermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        developer.log('Location services are disabled');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          developer.log('Location permissions are denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        developer.log('Location permissions are permanently denied');
        return false;
      }

      return true;
    } catch (e) {
      developer.log('Error checking location permission: $e');
      return false;
    }
  }

  Future<Position?> getCurrentPosition() async {
    try {
      if (!await ensurePermission()) {
        developer.log('Location permission not granted');
        return null;
      }

      // Use a timeout to prevent hanging
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      developer.log('Error getting current position: $e');
      return null;
    }
  }

  Stream<Position> watchPosition() {
    try {
      return Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update if moved 10 meters
        ),
      );
    } catch (e) {
      developer.log('Error watching position: $e');
      // Return an empty stream in case of error
      return Stream.empty();
    }
  }
}
