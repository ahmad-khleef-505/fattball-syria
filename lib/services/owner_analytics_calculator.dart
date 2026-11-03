import 'package:fattball/core/constants.dart';
import 'package:fattball/models/booking_model.dart';
import 'package:fattball/models/field_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class OwnerAnalyticsData {
  const OwnerAnalyticsData({
    required this.monthlyRevenue,
    required this.completedBookings,
    required this.bookedHours,
    required this.availableHours,
    required this.weeklyEarnings,
  });

  final double monthlyRevenue;
  final int completedBookings;
  final double bookedHours;
  final double availableHours;
  final List<double> weeklyEarnings;

  double get occupancyRate {
    if (availableHours <= 0) return 0;
    return (bookedHours / availableHours).clamp(0, 1).toDouble();
  }
}

class OwnerAnalyticsCalculator {
  OwnerAnalyticsCalculator._();

  static bool _timeZonesInitialized = false;

  static OwnerAnalyticsData calculate({
    required List<BookingModel> bookings,
    required List<FieldModel> fields,
    required UserModel owner,
    required DateTime now,
  }) {
    if (!_timeZonesInitialized) {
      timezone_data.initializeTimeZones();
      _timeZonesInitialized = true;
    }

    final location = timezone.getLocation(AppConstants.timeZone);
    final localNow = timezone.TZDateTime.from(now, location);
    final monthStart = timezone.TZDateTime(
      location,
      localNow.year,
      localNow.month,
    );
    final monthEnd = timezone.TZDateTime(
      location,
      localNow.year,
      localNow.month + 1,
    );
    final weekStart = timezone.TZDateTime(
      location,
      localNow.year,
      localNow.month,
      localNow.day - localNow.weekday + 1,
    );

    var monthlyRevenue = 0.0;
    var completedBookings = 0;
    final weeklyEarnings = List<double>.filled(7, 0);
    final fieldById = {for (final field in fields) field.fieldId: field};
    final occupancyIntervals = <String, List<_AnalyticsInterval>>{};

    for (final booking in bookings) {
      final start = timezone.TZDateTime.from(booking.startAt, location);
      final end = timezone.TZDateTime.from(booking.endAt, location);
      final startsThisMonth =
          !start.isBefore(monthStart) && !start.isAfter(localNow);

      if (booking.status == BookingStatus.completed && startsThisMonth) {
        monthlyRevenue += booking.totalPrice;
        completedBookings++;
      }

      if (booking.status == BookingStatus.completed &&
          !start.isBefore(weekStart) &&
          !start.isAfter(localNow)) {
        weeklyEarnings[start.weekday - DateTime.monday] += booking.totalPrice;
      }

      if (booking.status != BookingStatus.confirmed &&
          booking.status != BookingStatus.completed) {
        continue;
      }

      final field = fieldById[booking.fieldId];
      final expiry = field?.ownerSubscriptionExpiry;
      if (field == null ||
          !field.isActive ||
          !owner.isActive ||
          expiry == null) {
        continue;
      }
      final localExpiry = timezone.TZDateTime.from(expiry, location);
      if (!localExpiry.isAfter(monthStart)) continue;

      final intervalStart = _later(start, monthStart);
      final intervalEnd = _earlier(
        _earlier(end, monthEnd),
        localExpiry,
      );
      if (intervalEnd.isAfter(intervalStart)) {
        occupancyIntervals
            .putIfAbsent(booking.fieldId, () => [])
            .add(_AnalyticsInterval(intervalStart, intervalEnd));
      }
    }

    var availableHours = 0.0;
    if (owner.isActive) {
      for (final field in fields) {
        final expiry = field.ownerSubscriptionExpiry;
        if (!field.isActive || expiry == null) continue;

        final localExpiry = timezone.TZDateTime.from(expiry, location);
        if (!localExpiry.isAfter(monthStart)) continue;
        availableHours += _availableHours(
          field: field,
          monthStart: monthStart,
          monthEnd: monthEnd,
          expiry: localExpiry,
          location: location,
        );
      }
    }

    final bookedHours = occupancyIntervals.values.fold<double>(
      0,
      (total, intervals) => total + _mergedDurationHours(intervals),
    );

    return OwnerAnalyticsData(
      monthlyRevenue: monthlyRevenue,
      completedBookings: completedBookings,
      bookedHours: bookedHours,
      availableHours: availableHours,
      weeklyEarnings: List.unmodifiable(weeklyEarnings),
    );
  }

  static double _availableHours({
    required FieldModel field,
    required timezone.TZDateTime monthStart,
    required timezone.TZDateTime monthEnd,
    required timezone.TZDateTime expiry,
    required timezone.Location location,
  }) {
    final opening = _minutesSinceMidnight(field.openTime);
    final closing = _minutesSinceMidnight(field.closeTime);
    if (opening == closing) {
      throw const FormatException('ساعات عمل الملعب غير صالحة للتحليلات.');
    }

    final firstDay = monthStart.subtract(const Duration(days: 1));
    var total = 0.0;
    for (var day = firstDay;
        !day.isAfter(monthEnd);
        day = timezone.TZDateTime(
      location,
      day.year,
      day.month,
      day.day + 1,
    )) {
      final opensAt = timezone.TZDateTime(
        location,
        day.year,
        day.month,
        day.day,
        opening ~/ 60,
        opening % 60,
      );
      var closesAt = timezone.TZDateTime(
        location,
        day.year,
        day.month,
        day.day,
        closing ~/ 60,
        closing % 60,
      );
      if (closing < opening) {
        closesAt = closesAt.add(const Duration(days: 1));
      }

      final availableFrom = _later(opensAt, monthStart);
      final availableUntil = _earlier(_earlier(closesAt, monthEnd), expiry);
      if (availableUntil.isAfter(availableFrom)) {
        total += availableUntil.difference(availableFrom).inMinutes / 60;
      }
    }
    return total;
  }

  static int _minutesSinceMidnight(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      throw const FormatException('ساعات عمل الملعب غير صالحة للتحليلات.');
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw const FormatException('ساعات عمل الملعب غير صالحة للتحليلات.');
    }
    return hour * 60 + minute;
  }

  static double _mergedDurationHours(List<_AnalyticsInterval> intervals) {
    intervals.sort((first, second) => first.start.compareTo(second.start));
    var start = intervals.first.start;
    var end = intervals.first.end;
    var total = 0.0;

    for (final interval in intervals.skip(1)) {
      if (!interval.start.isAfter(end)) {
        if (interval.end.isAfter(end)) end = interval.end;
        continue;
      }
      total += end.difference(start).inMinutes / 60;
      start = interval.start;
      end = interval.end;
    }
    return total + end.difference(start).inMinutes / 60;
  }

  static timezone.TZDateTime _later(
    timezone.TZDateTime first,
    timezone.TZDateTime second,
  ) {
    return first.isAfter(second) ? first : second;
  }

  static timezone.TZDateTime _earlier(
    timezone.TZDateTime first,
    timezone.TZDateTime second,
  ) {
    return first.isBefore(second) ? first : second;
  }
}

class _AnalyticsInterval {
  const _AnalyticsInterval(this.start, this.end);

  final timezone.TZDateTime start;
  final timezone.TZDateTime end;
}
