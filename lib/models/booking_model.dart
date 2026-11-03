import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus { pending, confirmed, cancelled, completed }

class BookingModel {
  const BookingModel({
    required this.bookingId,
    required this.fieldId,
    required this.ownerId,
    required this.customerId,
    required this.customerName,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.totalPrice,
    required this.createdAt,
    this.subtotalPrice,
    this.promoCode,
    this.discountPercent = 0,
    this.depositRequired = false,
    this.depositAmount = 0,
    this.depositMethod,
    this.depositReceiptUrl,
    this.depositStatus = 'not_required',
    this.coachId,
    this.coachName,
    this.trainingChildName,
    this.trainingChildAge,
    this.coachPricePerHour = 0,
  });

  final String bookingId;
  final String fieldId;
  final String ownerId;
  final String customerId;
  final String customerName;
  final DateTime startAt;
  final DateTime endAt;
  final BookingStatus status;
  final double totalPrice;
  final DateTime createdAt;
  final double? subtotalPrice;
  final String? promoCode;
  final int discountPercent;
  final bool depositRequired;
  final double depositAmount;
  final String? depositMethod;
  final String? depositReceiptUrl;
  final String depositStatus;
  final String? coachId;
  final String? coachName;
  final String? trainingChildName;
  final int? trainingChildAge;
  final double coachPricePerHour;

  factory BookingModel.fromMap(String bookingId, Map<String, dynamic> map) {
    return BookingModel(
      bookingId: bookingId,
      fieldId: map['fieldId'] as String,
      ownerId: map['ownerId'] as String,
      customerId: map['customerId'] as String,
      customerName: map['customerName'] as String,
      startAt: _dateTimeFrom(map['startAt'], 'startAt'),
      endAt: _dateTimeFrom(map['endAt'], 'endAt'),
      status: BookingStatus.values.byName(map['status'] as String),
      totalPrice: (map['totalPrice'] as num).toDouble(),
      createdAt: _dateTimeFrom(map['createdAt'], 'createdAt'),
      subtotalPrice: (map['subtotalPrice'] as num?)?.toDouble(),
      promoCode: map['promoCode'] as String?,
      discountPercent: map['discountPercent'] as int? ?? 0,
      depositRequired: map['depositRequired'] as bool? ?? false,
      depositAmount: (map['depositAmount'] as num?)?.toDouble() ?? 0,
      depositMethod: map['depositMethod'] as String?,
      depositReceiptUrl: map['depositReceiptUrl'] as String?,
      depositStatus: map['depositStatus'] as String? ?? 'not_required',
      coachId: map['coachId'] as String?,
      coachName: map['coachName'] as String?,
      trainingChildName: map['trainingChildName'] as String?,
      trainingChildAge: map['trainingChildAge'] as int?,
      coachPricePerHour: (map['coachPricePerHour'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fieldId': fieldId,
      'ownerId': ownerId,
      'customerId': customerId,
      'customerName': customerName,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'status': status.name,
      'totalPrice': totalPrice,
      'createdAt': Timestamp.fromDate(createdAt),
      'subtotalPrice': subtotalPrice ?? totalPrice,
      'promoCode': promoCode,
      'discountPercent': discountPercent,
      'depositRequired': depositRequired,
      'depositAmount': depositAmount,
      'depositMethod': depositMethod,
      'depositReceiptUrl': depositReceiptUrl,
      'depositStatus': depositStatus,
      'coachId': coachId,
      'coachName': coachName,
      'trainingChildName': trainingChildName,
      'trainingChildAge': trainingChildAge,
      'coachPricePerHour': coachPricePerHour,
    };
  }
}

DateTime _dateTimeFrom(Object? value, String fieldName) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  throw FormatException('قيمة التاريخ غير صالحة للحقل $fieldName');
}
