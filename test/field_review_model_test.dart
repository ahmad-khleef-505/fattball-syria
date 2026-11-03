import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/field_review_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a verified field review', () {
    final createdAt = DateTime.utc(2026, 11, 3);
    final review = FieldReviewModel.fromMap(
      'customer-1',
      'field-1',
      {
        'fieldId': 'field-1',
        'customerId': 'customer-1',
        'bookingId': 'booking-1',
        'rating': 5,
        'comment': 'ملعب ممتاز',
        'createdAt': Timestamp.fromDate(createdAt),
      },
    );

    expect(review.fieldId, 'field-1');
    expect(review.customerId, 'customer-1');
    expect(review.rating, 5);
    expect(review.comment, 'ملعب ممتاز');
    expect(review.createdAt.toUtc(), createdAt);
  });

  test('rejects ratings outside the one-to-five range', () {
    expect(
      () => FieldReviewModel.fromMap('customer-1', 'field-1', {
        'customerId': 'customer-1',
        'bookingId': 'booking-1',
        'rating': 6,
        'comment': '',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 3)),
      }),
      throwsFormatException,
    );
  });
}
