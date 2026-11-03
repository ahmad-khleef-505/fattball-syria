import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/promo_code_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 11, 1);
  final expiry = DateTime.utc(2026, 11, 8);

  Map<String, dynamic> promoData({int percent = 10, bool active = true}) => {
        'code': 'FOOTBALL10',
        'fieldId': 'field-1',
        'ownerId': 'owner-1',
        'discountPercent': percent,
        'startsAt': Timestamp.fromDate(start),
        'expiresAt': Timestamp.fromDate(expiry),
        'isActive': active,
        'createdAt': Timestamp.fromDate(start),
      };

  test('parses promo details and checks its validity window', () {
    final promo = PromoCodeModel.fromMap(
      'FOOTBALL10',
      promoData(),
    );

    expect(promo.discountPercent, 10);
    expect(promo.isValidAt(start), isTrue);
    expect(promo.isValidAt(expiry), isFalse);
    expect(
      promo.isValidAt(start.subtract(const Duration(seconds: 1))),
      isFalse,
    );
  });

  test('round-trips promo code data', () {
    final promo = PromoCodeModel.fromMap(
      'FOOTBALL10',
      promoData(),
    );
    final restored = PromoCodeModel.fromMap(promo.code, promo.toMap());

    expect(restored.fieldId, promo.fieldId);
    expect(restored.ownerId, promo.ownerId);
    expect(restored.discountPercent, promo.discountPercent);
    expect(restored.expiresAt, promo.expiresAt);
  });

  test('rejects invalid discount percentages', () {
    expect(
      () => PromoCodeModel.fromMap(
        'FOOTBALL10',
        promoData(percent: 91),
      ),
      throwsFormatException,
    );
  });
}
