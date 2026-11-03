import 'package:cloud_firestore/cloud_firestore.dart';

class CoachModel {
  const CoachModel({
    required this.coachId,
    required this.fieldId,
    required this.ownerId,
    required this.name,
    required this.specialty,
    required this.bio,
    required this.pricePerHour,
    required this.isActive,
    required this.createdAt,
  });

  final String coachId;
  final String fieldId;
  final String ownerId;
  final String name;
  final String specialty;
  final String bio;
  final double pricePerHour;
  final bool isActive;
  final DateTime createdAt;

  factory CoachModel.fromMap(String coachId, Map<String, dynamic> map) {
    final createdAtValue = map['createdAt'];
    if (createdAtValue is! Timestamp && createdAtValue is! DateTime) {
      throw const FormatException('تاريخ إضافة المدرب غير صالح.');
    }
    final price = map['pricePerHour'];
    if (price is! num || !price.isFinite || price <= 0) {
      throw const FormatException('أجر المدرب المسجل غير صالح.');
    }

    return CoachModel(
      coachId: coachId,
      fieldId: map['fieldId'] as String,
      ownerId: map['ownerId'] as String,
      name: map['name'] as String,
      specialty: map['specialty'] as String,
      bio: map['bio'] as String,
      pricePerHour: price.toDouble(),
      isActive: map['isActive'] as bool,
      createdAt: createdAtValue is Timestamp
          ? createdAtValue.toDate()
          : createdAtValue as DateTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fieldId': fieldId,
      'ownerId': ownerId,
      'name': name,
      'specialty': specialty,
      'bio': bio,
      'pricePerHour': pricePerHour,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
