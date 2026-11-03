import 'package:cloud_firestore/cloud_firestore.dart';

class FieldReviewModel {
  const FieldReviewModel({
    required this.reviewId,
    required this.fieldId,
    required this.customerId,
    required this.bookingId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String reviewId;
  final String fieldId;
  final String customerId;
  final String bookingId;
  final int rating;
  final String comment;
  final DateTime createdAt;

  factory FieldReviewModel.fromMap(
    String reviewId,
    String fieldId,
    Map<String, dynamic> map,
  ) {
    final createdAtValue = map['createdAt'];
    if (createdAtValue is! Timestamp) {
      throw const FormatException('تاريخ التقييم غير صالح.');
    }
    final ratingValue = map['rating'];
    if (ratingValue is! int || ratingValue < 1 || ratingValue > 5) {
      throw const FormatException('قيمة النجوم في التقييم غير صالحة.');
    }
    final customerId = map['customerId'];
    final bookingId = map['bookingId'];
    final comment = map['comment'];
    if (customerId is! String || bookingId is! String || comment is! String) {
      throw const FormatException('بيانات التقييم غير مكتملة.');
    }

    return FieldReviewModel(
      reviewId: reviewId,
      fieldId: fieldId,
      customerId: customerId,
      bookingId: bookingId,
      rating: ratingValue,
      comment: comment,
      createdAt: createdAtValue.toDate(),
    );
  }
}
