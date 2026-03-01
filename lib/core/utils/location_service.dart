import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  /// Requests location permission if needed, then returns the city name.
  /// Returns null if permission denied or lookup fails.
  static Future<String?> getCurrentCity() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.reduced,
        timeLimit: Duration(seconds: 10),
      ),
    );

    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isEmpty) return null;
    final place = placemarks.first;
    // Return the most specific available city name
    return place.locality?.isNotEmpty == true
        ? place.locality
        : place.subAdministrativeArea?.isNotEmpty == true
            ? place.subAdministrativeArea
            : place.administrativeArea;
  }
}
