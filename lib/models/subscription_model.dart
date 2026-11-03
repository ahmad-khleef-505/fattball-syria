import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionModel {
  const SubscriptionModel({
    required this.id,
    required this.ownerId,
    required this.amountUsd,
    required this.startedAt,
    required this.expiresAt,
    required this.status,
    this.paymentRef,
    this.activatedBy,
  });

  final String id;
  final String ownerId;
  final double amountUsd;
  final DateTime startedAt;
  final DateTime expiresAt;
  final String status;
  final String? paymentRef;
  final String? activatedBy;

  factory SubscriptionModel.fromMap(String id, Map<String, dynamic> map) {
    return SubscriptionModel(
      id: id,
      ownerId: map['ownerId'] as String,
      amountUsd: (map['amountUsd'] as num).toDouble(),
      startedAt: _dateTimeFrom(map['startedAt'], 'startedAt'),
      expiresAt: _dateTimeFrom(map['expiresAt'], 'expiresAt'),
      status: map['status'] as String,
      paymentRef: map['paymentRef'] as String?,
      activatedBy: map['activatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'amountUsd': amountUsd,
      'startedAt': Timestamp.fromDate(startedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': status,
      'paymentRef': paymentRef,
      'activatedBy': activatedBy,
    };
  }
}

DateTime _dateTimeFrom(Object? value, String fieldName) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  throw FormatException('قيمة التاريخ غير صالحة للحقل $fieldName');
}
