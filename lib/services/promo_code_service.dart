import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/field_model.dart';
import 'package:fattball/models/promo_code_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final promoCodeServiceProvider = Provider<PromoCodeService>((ref) {
  return PromoCodeService();
});

final ownerPromoCodesProvider =
    StreamProvider.family<List<PromoCodeModel>, String>((ref, fieldId) {
  return ref.watch(promoCodeServiceProvider).watchFieldPromoCodes(fieldId);
});

class PromoCodeServiceException implements Exception {
  const PromoCodeServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PromoCodeService {
  PromoCodeService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<PromoCodeModel>> watchFieldPromoCodes(String fieldId) {
    return _firestore
        .collection('fields')
        .doc(fieldId)
        .collection('promo_codes')
        .snapshots()
        .map((snapshot) {
      final codes = snapshot.docs
          .map(
            (document) => PromoCodeModel.fromMap(
              document.id,
              document.data(),
            ),
          )
          .toList()
        ..sort((first, second) => first.expiresAt.compareTo(second.expiresAt));
      return codes;
    });
  }

  Future<PromoCodeModel> validatePromoCode({
    required String fieldId,
    required String ownerId,
    required String code,
    DateTime? now,
  }) async {
    final normalizedCode = normalizeCode(code);
    final snapshot = await _firestore
        .collection('fields')
        .doc(fieldId)
        .collection('promo_codes')
        .doc(normalizedCode)
        .get();
    final data = snapshot.data();
    if (data == null) {
      throw const PromoCodeServiceException('كود الخصم غير موجود.');
    }
    final promo = PromoCodeModel.fromMap(snapshot.id, data);
    if (promo.fieldId != fieldId || promo.ownerId != ownerId) {
      throw const PromoCodeServiceException(
        'كود الخصم غير صالح لهذا الملعب.',
      );
    }
    if (!promo.isValidAt(now ?? DateTime.now())) {
      throw const PromoCodeServiceException(
        'كود الخصم منتهي الصلاحية أو غير مفعّل حالياً.',
      );
    }
    return promo;
  }

  Future<void> createPromoCode({
    required FieldModel field,
    required String ownerId,
    required String code,
    required int discountPercent,
    required DateTime expiresAt,
  }) async {
    if (_auth.currentUser?.uid != ownerId || field.ownerId != ownerId) {
      throw const PromoCodeServiceException(
        'سجّل الدخول بحساب صاحب الملعب لإدارة أكواد الخصم.',
      );
    }
    final normalizedCode = normalizeCode(code);
    if (!RegExp(r'^[A-Z0-9]{4,20}$').hasMatch(normalizedCode)) {
      throw const PromoCodeServiceException(
        'استخدم 4 إلى 20 حرفاً إنجليزياً أو رقماً للكود.',
      );
    }
    if (discountPercent < 1 || discountPercent > 90) {
      throw const PromoCodeServiceException(
        'يجب أن تكون نسبة الخصم بين 1% و90%.',
      );
    }

    final now = DateTime.now();
    if (!expiresAt.isAfter(now)) {
      throw const PromoCodeServiceException(
        'يجب اختيار تاريخ انتهاء في المستقبل.',
      );
    }

    final fieldRef = _firestore.collection('fields').doc(field.fieldId);
    final promoRef = fieldRef.collection('promo_codes').doc(normalizedCode);
    try {
      await _firestore.runTransaction<void>((transaction) async {
        final fieldSnapshot = await transaction.get(fieldRef);
        final promoSnapshot = await transaction.get(promoRef);
        final fieldData = fieldSnapshot.data();
        if (fieldData == null || fieldData['ownerId'] != ownerId) {
          throw const PromoCodeServiceException(
            'الملعب غير موجود أو لا يتبع حسابك.',
          );
        }
        if (!fieldSnapshot.exists) {
          throw const PromoCodeServiceException('الملعب المطلوب غير موجود.');
        }
        if (promoSnapshot.exists) {
          throw const PromoCodeServiceException(
            'هذا الكود مستخدم مسبقاً لهذا الملعب.',
          );
        }
        transaction.set(
          promoRef,
          PromoCodeModel(
            code: normalizedCode,
            fieldId: field.fieldId,
            ownerId: ownerId,
            discountPercent: discountPercent,
            startsAt: now,
            expiresAt: expiresAt,
            isActive: true,
            createdAt: now,
          ).toMap(),
        );
      });
    } on PromoCodeServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw PromoCodeServiceException(_firebaseError(error.code));
    }
  }

  Future<void> deletePromoCode({
    required String fieldId,
    required String ownerId,
    required String code,
  }) async {
    if (_auth.currentUser?.uid != ownerId) {
      throw const PromoCodeServiceException(
        'سجّل الدخول بحساب صاحب الملعب لحذف الكود.',
      );
    }
    try {
      await _firestore
          .collection('fields')
          .doc(fieldId)
          .collection('promo_codes')
          .doc(normalizeCode(code))
          .delete();
    } on FirebaseException catch (error) {
      throw PromoCodeServiceException(_firebaseError(error.code));
    }
  }

  static String normalizeCode(String code) =>
      code.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();

  String _firebaseError(String code) {
    return switch (code) {
      'permission-denied' => 'ليست لديك صلاحية إدارة أكواد هذا الملعب.',
      'unavailable' => 'الخدمة غير متاحة حالياً. تحقق من اتصالك.',
      'already-exists' => 'هذا الكود مستخدم مسبقاً لهذا الملعب.',
      _ => 'تعذر تنفيذ طلب كود الخصم. يرجى المحاولة مجدداً.',
    };
  }
}
