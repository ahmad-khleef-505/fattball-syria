import 'dart:convert';

import 'package:fattball/services/weather_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

void main() {
  test('reads current governorate conditions from Open-Meteo', () async {
    final service = WeatherService(
      client: MockClient((request) async {
        expect(request.url.host, 'api.open-meteo.com');
        expect(request.url.queryParameters['timezone'], 'Asia/Damascus');
        return http.Response(
          jsonEncode({
            'current': {
              'weather_code': 0,
              'temperature_2m': 24.5,
              'precipitation': 0,
              'wind_speed_10m': 12,
            },
            'hourly': {'time': [], 'weather_code': []},
          }),
          200,
        );
      }),
    );
    addTearDown(service.dispose);

    final weather = await service.currentForGovernorate('حلب');

    expect(weather.description, 'صافٍ');
    expect(weather.temperatureC, 24.5);
    expect(weather.isSevere, isFalse);
  });

  test('flags thunderstorm and heavy rain for a booking hour', () async {
    final service = WeatherService(
      client: MockClient((_) async {
        return http.Response(
          jsonEncode({
            'current': {
              'weather_code': 3,
              'temperature_2m': 18,
              'precipitation': 0,
              'wind_speed_10m': 10,
            },
            'hourly': {
              'time': ['2026-11-03T05:00'],
              'weather_code': [95],
              'precipitation': [9.5],
              'precipitation_probability': [90],
              'wind_speed_10m': [68],
            },
          }),
          200,
        );
      }),
    );
    addTearDown(service.dispose);

    final weather = await service.forecastForBooking(
      latitude: 33.5,
      longitude: 36.2,
      startAt: DateTime(2026, 11, 3, 5),
    );

    expect(weather, isNotNull);
    expect(weather!.description, 'عواصف رعدية');
    expect(weather.isSevere, isTrue);
    expect(weather.windKmh, 68);
  });

  test('does not claim forecasts beyond Open-Meteo horizon', () async {
    var requestCount = 0;
    final service = WeatherService(
      client: MockClient((_) async {
        requestCount++;
        return http.Response('', 500);
      }),
    );
    addTearDown(service.dispose);

    final weather = await service.forecastForBooking(
      latitude: 33.5,
      longitude: 36.2,
      startAt: DateTime.now().add(const Duration(days: 20)),
    );

    expect(weather, isNull);
    expect(requestCount, 0);
  });
}
