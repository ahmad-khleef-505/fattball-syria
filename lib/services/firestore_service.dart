import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreServiceException implements Exception {
  const FirestoreServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<Map<String, dynamic>?> getDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      final snapshot =
          await _firestore.collection(collection).doc(documentId).get();
      return snapshot.data();
    } on FirebaseException catch (error) {
      throw FirestoreServiceException(_errorMessage(error.code));
    }
  }

  Future<void> createDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection(collection).doc(documentId).set(data);
    } on FirebaseException catch (error) {
      throw FirestoreServiceException(_errorMessage(error.code));
    }
  }

  Future<void> updateDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection(collection).doc(documentId).update(data);
    } on FirebaseException catch (error) {
      throw FirestoreServiceException(_errorMessage(error.code));
    }
  }

  Future<void> deleteDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      await _firestore.collection(collection).doc(documentId).delete();
    } on FirebaseException catch (error) {
      throw FirestoreServiceException(_errorMessage(error.code));
    }
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchCollection({
    required String collection,
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>> query)?
        queryBuilder,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(collection);
    if (queryBuilder != null) query = queryBuilder(query);
    return query.snapshots().map((snapshot) => snapshot.docs);
  }

  String _errorMessage(String code) {
    return switch (code) {
      'permission-denied' => 'ليست لديك صلاحية لتنفيذ هذا الإجراء.',
      'not-found' => 'البيانات المطلوبة غير موجودة.',
      'already-exists' => 'البيانات موجودة مسبقاً.',
      'unavailable' => 'الخدمة غير متاحة حالياً. تحقق من اتصالك.',
      'deadline-exceeded' => 'استغرق الطلب وقتاً طويلاً. يرجى المحاولة مجدداً.',
      'failed-precondition' => 'تعذر إكمال العملية بسبب حالة البيانات الحالية.',
      _ => 'حدث خطأ أثناء التعامل مع البيانات. يرجى المحاولة مجدداً.',
    };
  }
}
