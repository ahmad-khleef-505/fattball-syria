import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CoachService {
  CoachService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _coaches(String fieldId) =>
      _firestore.collection('fields').doc(fieldId).collection('coaches');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCoaches(
    String fieldId, {
    required bool activeOnly,
  }) {
    final collection = _coaches(fieldId);
    return activeOnly
        ? collection.where('isActive', isEqualTo: true).snapshots()
        : collection.snapshots();
  }

  Future<void> createCoach({
    required String fieldId,
    required String ownerId,
    required String name,
    required String specialty,
    required String bio,
    required double pricePerHour,
  }) async {
    _requireOwner(ownerId);
    final normalizedName = name.trim();
    final normalizedSpecialty = specialty.trim();
    final normalizedBio = bio.trim();
    if (normalizedName.length < 2 || normalizedName.length > 80) {
      throw const CoachServiceException('اسم المدرب يجب أن يكون بين حرفين و80 حرفاً.');
    }
    if (normalizedSpecialty.isEmpty || normalizedSpecialty.length > 80) {
      throw const CoachServiceException('أدخل اختصاصاً لا يتجاوز 80 حرفاً.');
    }
    if (normalizedBio.length > 500) {
      throw const CoachServiceException('نبذة المدرب لا تتجاوز 500 حرف.');
    }
    if (!pricePerHour.isFinite || pricePerHour <= 0 || pricePerHour > 10000) {
      throw const CoachServiceException('أجر التدريب بالساعة غير صالح.');
    }

    final coachRef = _coaches(fieldId).doc();
    try {
      await coachRef.set({
        'fieldId': fieldId,
        'ownerId': ownerId,
        'name': normalizedName,
        'specialty': normalizedSpecialty,
        'bio': normalizedBio,
        'pricePerHour': pricePerHour,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw CoachServiceException(_errorMessage(error.code));
    }
  }

  Future<void> setCoachActive({
    required String fieldId,
    required String ownerId,
    required String coachId,
    required bool isActive,
  }) async {
    _requireOwner(ownerId);
    try {
      await _coaches(fieldId).doc(coachId).update({'isActive': isActive});
    } on FirebaseException catch (error) {
      throw CoachServiceException(_errorMessage(error.code));
    }
  }

  Future<void> deleteCoach({
    required String fieldId,
    required String ownerId,
    required String coachId,
  }) async {
    _requireOwner(ownerId);
    try {
      await _coaches(fieldId).doc(coachId).delete();
    } on FirebaseException catch (error) {
      throw CoachServiceException(_errorMessage(error.code));
    }
  }

  void _requireOwner(String ownerId) {
    if (_auth.currentUser?.uid != ownerId) {
      throw const CoachServiceException(
        'سجّل الدخول بحساب صاحب الملعب لتنفيذ هذا الإجراء.',
      );
    }
  }

  String _errorMessage(String code) {
    return switch (code) {
      'permission-denied' => 'ليست لديك صلاحية إدارة مدربي هذا الملعب.',
      'not-found' => 'المدرب أو الملعب غير موجود.',
      'unavailable' => 'الخدمة غير متاحة حالياً. تحقق من اتصالك.',
      _ => 'تعذر حفظ بيانات المدرب. حاول مرة أخرى.',
    };
  }
}

class CoachServiceException implements Exception {
  const CoachServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
