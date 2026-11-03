import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/booking_model.dart';
import 'package:fattball/models/field_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/services/owner_analytics_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as timezone;
import 'package:timezone/data/latest.dart' as timezone_data;

void main() {
  setUpAll(timezone_data.initializeTimeZones);

  test('calculates month earnings and current-week daily earnings', () {
    final damascus = timezone.getLocation('Asia/Damascus');
    final now = timezone.TZDateTime(damascus, 2026, 11, 1, 10);
    final field = _field(
      expiry: timezone.TZDateTime(damascus, 2026, 12, 1),
    );
    final completed = _booking(
      id: 'completed',
      status: BookingStatus.completed,
      startAt: timezone.TZDateTime(damascus, 2026, 11, 1, 8),
      endAt: timezone.TZDateTime(damascus, 2026, 11, 1, 9),
      price: 40,
    );
    final confirmed = _booking(
      id: 'confirmed',
      status: BookingStatus.confirmed,
      startAt: timezone.TZDateTime(damascus, 2026, 11, 1, 9),
      endAt: timezone.TZDateTime(damascus, 2026, 11, 1, 10),
      price: 20,
    );
    final futureConfirmed = _booking(
      id: 'future-confirmed',
      status: BookingStatus.confirmed,
      startAt: timezone.TZDateTime(damascus, 2026, 11, 10, 8),
      endAt: timezone.TZDateTime(damascus, 2026, 11, 10, 10),
      price: 40,
    );
    final cancelled = _booking(
      id: 'cancelled',
      status: BookingStatus.cancelled,
      startAt: timezone.TZDateTime(damascus, 2026, 11, 1, 8),
      endAt: timezone.TZDateTime(damascus, 2026, 11, 1, 10),
      price: 100,
    );

    final result = OwnerAnalyticsCalculator.calculate(
      bookings: [completed, confirmed, futureConfirmed, cancelled],
      fields: [field],
      owner: _owner,
      now: now,
    );

    expect(result.monthlyRevenue, 40);
    expect(result.completedBookings, 1);
    expect(result.todayBookings, 2);
    expect(result.expectedRevenue, 40);
    expect(result.ownedFields, 1);
    expect(result.weeklyEarnings, [0, 0, 0, 0, 0, 0, 40]);
    expect(result.bookedHours, 4);
    expect(result.availableHours, 360);
    expect(result.occupancyRate, closeTo(4 / 360, 0.00001));
  });

  test('clips occupancy and availability at the subscription expiry', () {
    final damascus = timezone.getLocation('Asia/Damascus');
    final now = timezone.TZDateTime(damascus, 2026, 11, 1, 12);
    final field = _field(
      expiry: timezone.TZDateTime(damascus, 2026, 11, 1, 9),
    );
    final booking = _booking(
      id: 'booking',
      status: BookingStatus.completed,
      startAt: timezone.TZDateTime(damascus, 2026, 11, 1, 8),
      endAt: timezone.TZDateTime(damascus, 2026, 11, 1, 10),
      price: 40,
    );

    final result = OwnerAnalyticsCalculator.calculate(
      bookings: [booking],
      fields: [field],
      owner: _owner,
      now: now,
    );

    expect(result.bookedHours, 1);
    expect(result.availableHours, 1);
    expect(result.occupancyRate, 1);
  });
}

final _owner = UserModel(
  uid: 'owner-1',
  name: 'صاحب الملعب',
  email: 'owner@example.com',
  role: 'owner',
  createdAt: DateTime.utc(2026),
  isActive: true,
);

FieldModel _field({required DateTime expiry}) {
  return FieldModel(
    fieldId: 'field-1',
    ownerId: _owner.uid,
    name: 'ملعب المدينة',
    description: 'ملعب تجريبي',
    governorate: 'دمشق',
    district: 'المزة',
    address: 'دمشق',
    geoPoint: const GeoPoint(33.5, 36.2),
    pricePerHour: 20,
    openTime: '08:00',
    closeTime: '20:00',
    images: const [],
    isActive: true,
    ownerSubscriptionExpiry: expiry,
    createdAt: DateTime.utc(2026),
  );
}

BookingModel _booking({
  required String id,
  required BookingStatus status,
  required DateTime startAt,
  required DateTime endAt,
  required double price,
}) {
  return BookingModel(
    bookingId: id,
    fieldId: 'field-1',
    ownerId: _owner.uid,
    customerId: 'customer-1',
    customerName: 'لاعب',
    startAt: startAt,
    endAt: endAt,
    status: status,
    totalPrice: price,
    createdAt: startAt,
  );
}
