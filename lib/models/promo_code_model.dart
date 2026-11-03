import 'package:cloud_firestore/cloud_firestore.dart';

class PromoCodeModel {
  const PromoCodeModel({
    required this.code,
    required this.fieldId,
    required this.ownerId,
    required this.discountPercent,
    required this.startsAt,
    required this.expiresAt,
    required this.isActive,
    required this.createdAt,
  });

  final String code;
  final String fieldId;
  final String ownerId;
  final int discountPercent;
  final DateTime startsAt;
  final DateTime expiresAt;
  final bool isActive;
  final DateTime createdAt;

  bool isValidAt(DateTime time) =>
      isActive &&
      !time.isBefore(startsAt) &&
      time.isBefore(expiresAt);

  factory PromoCodeModel.fromMap(
    String code,
    Map<String, dynamic> map,
  ) {
    final percent = map['discountPercent'];
    if (percent is! int || percent < 1 || percent > 90) {
      throw const FormatException('نسبة الخصم غير صالحة.');
    }
    final fieldId = map['fieldId'];
    final ownerId = map['ownerId'];
    final storedCode = map['code'];
    final isActive = map['isActive'];
    if (storedCode != code ||
        fieldId is! String ||
        ownerId is! String ||
        isActive is! bool) {
      throw const FormatException('بيانات كود الخصم غير مكتملة.');
    }
    final startsAt = _promoDate(map['startsAt'], 'startsAt');
    final expiresAt = _promoDate(map['expiresAt'], 'expiresAt');
    if (!expiresAt.isAfter(startsAt)) {
      throw const FormatException('فترة صلاحية كود الخصم غير صالحة.');
    }
    return PromoCodeModel(
      code: code,
      fieldId: fieldId,
      ownerId: ownerId,
      discountPercent: percent,
      startsAt: startsAt,
      expiresAt: expiresAt,
      isActive: isActive,
      createdAt: _promoDate(map['createdAt'], 'createdAt'),
    );
  }

  Map<String, dynamic> toMap() => {
        'code': code,
        'fieldId': fieldId,
        'ownerId': ownerId,
        'discountPercent': discountPercent,
        'startsAt': Timestamp.fromDate(startsAt),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

DateTime _promoDate(Object? value, String fieldName) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  throw FormatException('تاريخ كود الخصم غير صالح: $fieldName');
}
