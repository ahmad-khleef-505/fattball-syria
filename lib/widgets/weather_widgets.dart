import 'package:fattball/models/field_model.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/services/weather_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WeatherSummaryCard extends ConsumerWidget {
  const WeatherSummaryCard({super.key, this.governorate});

  final String? governorate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(weatherServiceProvider);
    return FutureBuilder<WeatherSnapshot>(
      future: service.currentForGovernorate(governorate),
      builder: (context, snapshot) {
        return Card(
          margin: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Text(
                  snapshot.data?.icon ?? '🌤️',
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    snapshot.hasError
                        ? 'الطقس غير متاح حالياً'
                        : snapshot.data == null
                            ? 'جارٍ تحميل الطقس...'
                            : 'الطقس في ${governorate ?? 'دمشق'}: '
                                '${snapshot.data!.description}، '
                                '${snapshot.data!.temperatureC.round()}°',
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (snapshot.hasError)
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  )
                else
                  Text(
                    snapshot.data!.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class BookingWeatherAlert extends ConsumerWidget {
  const BookingWeatherAlert({
    super.key,
    required this.field,
    required this.startAt,
  });

  final FieldModel field;
  final DateTime startAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecast = ref.watch(weatherServiceProvider).forecastForBooking(
          latitude: field.geoPoint.latitude,
          longitude: field.geoPoint.longitude,
          startAt: startAt,
        );
    return FutureBuilder<WeatherSnapshot?>(
      future: forecast,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            leading: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text('جارٍ التحقق من طقس موعد الحجز...'),
          );
        }
        if (snapshot.hasError) {
          return const ListTile(
            leading: Icon(Icons.cloud_off_outlined),
            title: Text('تعذر جلب توقعات الطقس لهذا الموعد.'),
          );
        }
        final weather = snapshot.data;
        if (weather == null) {
          return const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('لا تتوفر توقعات موثوقة لهذا الموعد بعد.'),
          );
        }
        if (!weather.isSevere) {
          return ListTile(
            leading: Text(weather.icon, style: const TextStyle(fontSize: 22)),
            title: Text('توقعات الموعد: ${weather.description}'),
            subtitle: Text(
              'احتمال الهطول ${weather.precipitationMm.toStringAsFixed(1)} مم، '
              'الرياح ${weather.windKmh.round()} كم/ساعة.',
            ),
          );
        }
        return ListTile(
          leading: Icon(
            Icons.thunderstorm_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          title: const Text('الطقس غير مناسب، هل تريد إعادة الجدولة مجاناً؟'),
          subtitle: Text(
            '${weather.description} — هطول '
            '${weather.precipitationMm.toStringAsFixed(1)} مم ورياح '
            '${weather.windKmh.round()} كم/ساعة. نسّق مع صاحب الملعب لإعادة '
            'الجدولة دون رسوم قبل إلغاء الحجز.',
          ),
          isThreeLine: true,
        );
      },
    );
  }
}
