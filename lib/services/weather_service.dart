import 'dart:convert';

import 'package:http/http.dart' as http;

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.description,
    required this.icon,
    required this.temperatureC,
    this.isSevere = false,
    this.windKmh = 0,
    this.precipitationMm = 0,
  });

  final String description;
  final String icon;
  final double temperatureC;
  final bool isSevere;
  final double windKmh;
  final double precipitationMm;
}

class WeatherServiceException implements Exception {
  const WeatherServiceException(this.message);
  final String message;
}

class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, ({DateTime fetchedAt, Map<String, dynamic> data})> _cache =
      {};

  void dispose() => _client.close();

  static const Map<String, (double, double)> _governorateCoordinates = {
    'دمشق': (33.5138, 36.2765),
    'ريف دمشق': (33.5138, 36.2765),
    'حلب': (36.2021, 37.1343),
    'حمص': (34.7324, 36.7137),
    'حماة': (35.1318, 36.7515),
    'اللاذقية': (35.5317, 35.7901),
    'طرطوس': (34.8890, 35.8866),
    'إدلب': (35.9306, 36.6339),
    'الحسكة': (36.5024, 40.7477),
    'دير الزور': (35.3359, 40.1408),
    'الرقة': (35.9594, 38.9981),
    'درعا': (32.6189, 36.1021),
    'السويداء': (32.7089, 36.5695),
    'القنيطرة': (33.1250, 35.8240),
  };

  Future<WeatherSnapshot> currentForGovernorate(String? governorate) async {
    final coordinates = _governorateCoordinates[governorate] ??
        _governorateCoordinates['دمشق']!;
    final data = await _forecast(coordinates.$1, coordinates.$2);
    final current = data['current'];
    if (current is! Map<String, dynamic>) {
      throw const WeatherServiceException('لا تتوفر قراءة الطقس الحالية.');
    }
    return _snapshot(
      current['weather_code'] as num?,
      current['temperature_2m'] as num? ?? 0,
      current['precipitation'] as num? ?? 0,
      current['wind_speed_10m'] as num? ?? 0,
      0,
    );
  }

  Future<WeatherSnapshot?> forecastForBooking({
    required double latitude,
    required double longitude,
    required DateTime startAt,
  }) async {
    if (startAt.isAfter(DateTime.now().add(const Duration(days: 15)))) {
      return null;
    }
    final data = await _forecast(latitude, longitude);
    final hourly = data['hourly'];
    if (hourly is! Map<String, dynamic> ||
        hourly['time'] is! List ||
        hourly['weather_code'] is! List) {
      throw const WeatherServiceException('تعذر قراءة توقعات موعد الحجز.');
    }
    final times = List<String>.from(hourly['time'] as List);
    final index = times.indexWhere((value) {
      final forecastTime = DateTime.tryParse(value);
      return forecastTime != null &&
          forecastTime.year == startAt.year &&
          forecastTime.month == startAt.month &&
          forecastTime.day == startAt.day &&
          forecastTime.hour == startAt.hour;
    });
    if (index < 0) return null;
    num atIndex(String key) {
      final values = hourly[key];
      if (values is! List || index >= values.length) return 0;
      return values[index] as num? ?? 0;
    }

    return _snapshot(
      (hourly['weather_code'] as List)[index] as num?,
      0,
      atIndex('precipitation'),
      atIndex('wind_speed_10m'),
      atIndex('precipitation_probability'),
    );
  }

  Future<Map<String, dynamic>> _forecast(
    double latitude,
    double longitude,
  ) async {
    final key =
        '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) <
            const Duration(minutes: 15)) {
      return cached.data;
    }

    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': 'temperature_2m,precipitation,weather_code,wind_speed_10m',
      'hourly':
          'weather_code,precipitation,precipitation_probability,wind_speed_10m',
      'forecast_days': '16',
      'timezone': 'Asia/Damascus',
    });
    final response = await _client.get(uri).timeout(
          const Duration(seconds: 12),
        );
    if (response.statusCode != 200) {
      throw WeatherServiceException(
        'تعذر جلب الطقس (HTTP ${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const WeatherServiceException('استجابة الطقس غير صالحة.');
    }
    _cache[key] = (fetchedAt: DateTime.now(), data: decoded);
    return decoded;
  }

  WeatherSnapshot _snapshot(
    num? code,
    num temperature,
    num precipitation,
    num windKmh,
    num precipitationProbability,
  ) {
    final weatherCode = code?.toInt() ?? -1;
    final (description, icon) = switch (weatherCode) {
      0 => ('صافٍ', '☀️'),
      1 || 2 => ('غائم جزئياً', '🌤️'),
      3 => ('غائم', '☁️'),
      45 || 48 => ('ضبابي', '🌫️'),
      51 || 53 || 55 || 56 || 57 => ('رذاذ', '🌦️'),
      61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 => ('ممطر', '🌧️'),
      71 || 73 || 75 || 77 || 85 || 86 => ('ثلجي', '🌨️'),
      95 || 96 || 99 => ('عواصف رعدية', '⛈️'),
      _ => ('غير معروف', '🌡️'),
    };
    final heavyRain = precipitation >= 7 ||
        precipitationProbability >= 75 && precipitation >= 2 ||
        [65, 67, 82].contains(weatherCode);
    final storm = [95, 96, 99].contains(weatherCode) || windKmh >= 60;
    return WeatherSnapshot(
      description: description,
      icon: icon,
      temperatureC: temperature.toDouble(),
      isSevere: heavyRain || storm,
      windKmh: windKmh.toDouble(),
      precipitationMm: precipitation.toDouble(),
    );
  }
}
