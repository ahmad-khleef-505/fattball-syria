import 'package:cloud_firestore/cloud_firestore.dart';

class AdminLogModel {
  const AdminLogModel({
    required this.id,
    required this.adminUid,
    required this.action,
    required this.targetUid,
    required this.details,
    required this.createdAt,
  });

  final String id;
  final String adminUid;
  final String action;
  final String targetUid;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  factory AdminLogModel.fromMap(String id, Map<String, dynamic> map) {
    return AdminLogModel(
      id: id,
      adminUid: map['adminUid'] as String,
      action: map['action'] as String,
      targetUid: map['targetUid'] as String,
      details: Map<String, dynamic>.from(map['details'] as Map),
      createdAt: _dateTimeFrom(map['createdAt'], 'createdAt'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adminUid': adminUid,
      'action': action,
      'targetUid': targetUid,
      'details': details,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

DateTime _dateTimeFrom(Object? value, String fieldName) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  throw FormatException('قيمة التاريخ غير صالحة للحقل $fieldName');
}
