import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationServiceException implements Exception {
  const LocationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocationService {
  Future<LatLng> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException(
        'خدمة الموقع متوقفة. فعّلها من إعدادات الجهاز.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationServiceException('لم يتم منح إذن الوصول إلى الموقع.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
        'إذن الموقع مرفوض نهائياً. فعّله من إعدادات التطبيق.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } on LocationServiceDisabledException {
      throw const LocationServiceException(
        'خدمة الموقع متوقفة. فعّلها من إعدادات الجهاز.',
      );
    } on PermissionDeniedException {
      throw const LocationServiceException('لم يتم منح إذن الوصول إلى الموقع.');
    } on TimeoutException {
      throw const LocationServiceException('تعذر تحديد موقعك الحالي.');
    }
  }
}
