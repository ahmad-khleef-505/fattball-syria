import 'package:cloud_firestore/cloud_firestore.dart';

class FieldModel {
  const FieldModel({
    required this.fieldId,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.governorate,
    required this.district,
    required this.address,
    required this.geoPoint,
    required this.pricePerHour,
    required this.openTime,
    required this.closeTime,
    required this.images,
    required this.isActive,
    required this.createdAt,
    this.ownerSubscriptionExpiry,
    this.ownerPhone,
  });

  final String fieldId;
  final String ownerId;
  final String name;
  final String description;
  final String governorate;
  final String district;
  final String address;
  final GeoPoint geoPoint;
  final double pricePerHour;
  final String openTime;
  final String closeTime;
  final List<String> images;
  final bool isActive;
  final DateTime? ownerSubscriptionExpiry;
  final DateTime createdAt;
  final String? ownerPhone;

  factory FieldModel.fromMap(String fieldId, Map<String, dynamic> map) {
    final geoPoint = map['geoPoint'];
    if (geoPoint is! GeoPoint) {
      throw const FormatException('موقع الملعب غير صالح');
    }

    return FieldModel(
      fieldId: fieldId,
      ownerId: map['ownerId'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      governorate: map['governorate'] as String,
      district: map['district'] as String,
      address: map['address'] as String,
      geoPoint: geoPoint,
      pricePerHour: (map['pricePerHour'] as num).toDouble(),
      openTime: map['openTime'] as String,
      closeTime: map['closeTime'] as String,
      images: List<String>.from(map['images'] as List<dynamic>),
      isActive: map['isActive'] as bool,
      ownerSubscriptionExpiry: map['ownerSubscriptionExpiry'] == null
          ? null
          : _dateTimeFrom(
              map['ownerSubscriptionExpiry'],
              'ownerSubscriptionExpiry',
            ),
      createdAt: _dateTimeFrom(map['createdAt'], 'createdAt'),
      ownerPhone: map['ownerPhone'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'name': name,
      'description': description,
      'governorate': governorate,
      'district': district,
      'address': address,
      'geoPoint': geoPoint,
      'pricePerHour': pricePerHour,
      'openTime': openTime,
      'closeTime': closeTime,
      'images': images,
      'isActive': isActive,
      'ownerSubscriptionExpiry': ownerSubscriptionExpiry == null
          ? null
          : Timestamp.fromDate(ownerSubscriptionExpiry!),
      'createdAt': Timestamp.fromDate(createdAt),
      'ownerPhone': ownerPhone,
    };
  }
}

DateTime _dateTimeFrom(Object? value, String fieldName) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  throw FormatException('قيمة التاريخ غير صالحة للحقل $fieldName');
}
