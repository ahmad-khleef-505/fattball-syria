import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.isActive,
    this.phone,
    this.subscriptionExpiry,
    this.fcmToken,
  });

  final String uid;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final DateTime createdAt;
  final bool isActive;
  final DateTime? subscriptionExpiry;
  final String? fcmToken;

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      name: map['name'] as String,
      email: map['email'] as String,
      role: map['role'] as String,
      phone: map['phone'] as String?,
      createdAt: _dateTimeFrom(map['createdAt'], 'createdAt'),
      isActive: map['isActive'] as bool,
      subscriptionExpiry: map['subscriptionExpiry'] == null
          ? null
          : _dateTimeFrom(map['subscriptionExpiry'], 'subscriptionExpiry'),
      fcmToken: map['fcmToken'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'subscriptionExpiry': subscriptionExpiry == null
          ? null
          : Timestamp.fromDate(subscriptionExpiry!),
      'fcmToken': fcmToken,
    };
  }
}

DateTime _dateTimeFrom(Object? value, String fieldName) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  throw FormatException('قيمة التاريخ غير صالحة للحقل $fieldName');
}
