import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/booking_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final startAt = DateTime.utc(2026, 12, 1, 16);
  final endAt = startAt.add(const Duration(hours: 1));

  Map<String, dynamic> bookingData() => {
        'fieldId': 'field-1',
        'ownerId': 'owner-1',
        'customerId': 'customer-1',
        'customerName': 'عميل',
        'startAt': Timestamp.fromDate(startAt),
        'endAt': Timestamp.fromDate(endAt),
        'status': 'pending',
        'totalPrice': 100.0,
        'createdAt': Timestamp.fromDate(startAt),
      };

  test('reads older bookings without deposit fields', () {
    final booking = BookingModel.fromMap('booking-1', bookingData());

    expect(booking.depositRequired, isFalse);
    expect(booking.depositAmount, 0);
    expect(booking.depositStatus, 'not_required');
    expect(booking.coachId, isNull);
    expect(booking.coachPricePerHour, 0);
  });

  test('round-trips deposit details', () {
    final booking = BookingModel.fromMap('booking-1', {
      ...bookingData(),
      'depositRequired': true,
      'depositAmount': 20.0,
      'depositMethod': 'sham_cash',
      'depositReceiptUrl': 'https://firebasestorage.googleapis.com/example',
      'depositStatus': 'pending_approval',
    });

    final serialized = booking.toMap();
    expect(serialized['depositRequired'], isTrue);
    expect(serialized['depositAmount'], 20);
    expect(serialized['depositMethod'], 'sham_cash');
    expect(serialized['depositReceiptUrl'], contains('firebasestorage'));
    expect(serialized['depositStatus'], 'pending_approval');
  });

  test('round-trips promo pricing while keeping legacy booking defaults', () {
    final legacy = BookingModel.fromMap('legacy', bookingData());
    expect(legacy.subtotalPrice, isNull);
    expect(legacy.promoCode, isNull);
    expect(legacy.discountPercent, 0);

    final booking = BookingModel(
      bookingId: 'discounted',
      fieldId: 'field-1',
      ownerId: 'owner-1',
      customerId: 'customer-1',
      customerName: 'عميل',
      startAt: startAt,
      endAt: endAt,
      status: BookingStatus.pending,
      totalPrice: 90,
      subtotalPrice: 100,
      promoCode: 'FOOTBALL10',
      discountPercent: 10,
      createdAt: startAt,
    );
    final restored = BookingModel.fromMap(
      booking.bookingId,
      booking.toMap(),
    );

    expect(restored.subtotalPrice, 100);
    expect(restored.totalPrice, 90);
    expect(restored.promoCode, 'FOOTBALL10');
    expect(restored.discountPercent, 10);
  });

  test('round-trips a child training session and coach pricing', () {
    final booking = BookingModel(
      bookingId: 'training',
      fieldId: 'field-1',
      ownerId: 'owner-1',
      customerId: 'customer-1',
      customerName: 'ولي الأمر',
      startAt: startAt,
      endAt: endAt,
      status: BookingStatus.pending,
      totalPrice: 75,
      subtotalPrice: 75,
      createdAt: startAt,
      coachId: 'coach-1',
      coachName: 'المدرب',
      trainingChildName: 'الطفل',
      trainingChildAge: 10,
      coachPricePerHour: 25,
    );

    final restored = BookingModel.fromMap(booking.bookingId, booking.toMap());

    expect(restored.coachId, 'coach-1');
    expect(restored.coachName, 'المدرب');
    expect(restored.trainingChildName, 'الطفل');
    expect(restored.trainingChildAge, 10);
    expect(restored.coachPricePerHour, 25);
  });
}
