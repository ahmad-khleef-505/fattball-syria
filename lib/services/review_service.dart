import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/booking_model.dart';
import 'package:fattball/models/field_review_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef ReviewBookingQuery = ({String fieldId, String customerId});

final reviewServiceProvider = Provider<ReviewService>((ref) {
  return ReviewService();
});

final fieldReviewsProvider =
    StreamProvider.family<List<FieldReviewModel>, String>((ref, fieldId) {
  return ref.watch(reviewServiceProvider).watchFieldReviews(fieldId);
});

final reviewEligibleBookingsProvider =
    StreamProvider.family<List<BookingModel>, ReviewBookingQuery>(
  (ref, query) {
    return ref.watch(reviewServiceProvider).watchCompletedBookings(
          fieldId: query.fieldId,
          customerId: query.customerId,
        );
  },
);

class ReviewServiceException implements Exception {
  const ReviewServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReviewService {
  ReviewService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<FieldReviewModel>> watchFieldReviews(String fieldId) {
    return _firestore
        .collection('fields')
        .doc(fieldId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) => FieldReviewModel.fromMap(
                  document.id,
                  fieldId,
                  document.data(),
                ),
              )
              .toList(),
        );
  }

  Stream<List<BookingModel>> watchCompletedBookings({
    required String fieldId,
    required String customerId,
  }) {
    return _firestore
        .collection('bookings')
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
      final bookings = snapshot.docs
          .where(
            (document) =>
                document.data()['fieldId'] == fieldId &&
                document.data()['status'] == BookingStatus.completed.name,
          )
          .map(
            (document) => BookingModel.fromMap(
              document.id,
              document.data(),
            ),
          )
          .toList()
        ..sort((first, second) => second.endAt.compareTo(first.endAt));
      return bookings;
    });
  }

  Future<void> submitReview({
    required String fieldId,
    required UserModel customer,
    required String bookingId,
    required int rating,
    required String comment,
  }) async {
    if (_auth.currentUser?.uid != customer.uid ||
        customer.role != 'customer' ||
        !customer.isActive) {
      throw const ReviewServiceException(
        'سجّل الدخول بحساب عميل فعّال لإرسال التقييم.',
      );
    }
    if (rating < 1 || rating > 5) {
      throw const ReviewServiceException('اختر تقييماً من نجمة إلى خمس نجوم.');
    }
    final normalizedComment = comment.trim();
    if (normalizedComment.length > 500) {
      throw const ReviewServiceException(
        'يجب ألا يتجاوز التعليق 500 حرف.',
      );
    }

    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    final fieldRef = _firestore.collection('fields').doc(fieldId);
    final reviewRef = fieldRef.collection('reviews').doc(customer.uid);
    try {
      await _firestore.runTransaction<void>((transaction) async {
        final bookingSnapshot = await transaction.get(bookingRef);
        final fieldSnapshot = await transaction.get(fieldRef);
        final reviewSnapshot = await transaction.get(reviewRef);
        final booking = bookingSnapshot.data();
        final field = fieldSnapshot.data();

        if (booking == null ||
            booking['customerId'] != customer.uid ||
            booking['fieldId'] != fieldId ||
            booking['status'] != BookingStatus.completed.name) {
          throw const ReviewServiceException(
            'يمكنك تقييم الملعب بعد إكمال حجز فيه فقط.',
          );
        }
        if (field == null || field['ownerId'] != booking['ownerId']) {
          throw const ReviewServiceException('بيانات الملعب غير صالحة.');
        }
        if (reviewSnapshot.exists) {
          throw const ReviewServiceException(
            'سبق أن قيّمت هذا الملعب. شكراً لمشاركتك.',
          );
        }

        transaction.set(reviewRef, {
          'fieldId': fieldId,
          'customerId': customer.uid,
          'bookingId': bookingId,
          'rating': rating,
          'comment': normalizedComment,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on ReviewServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw ReviewServiceException(_firebaseError(error.code));
    }
  }

  String _firebaseError(String code) {
    return switch (code) {
      'permission-denied' => 'لا يمكن إرسال التقييم لهذا الحجز.',
      'unavailable' => 'الخدمة غير متاحة حالياً. تحقق من اتصالك.',
      'already-exists' => 'سبق أن قيّمت هذا الملعب.',
      _ => 'تعذر إرسال التقييم. يرجى المحاولة مجدداً.',
    };
  }
}
