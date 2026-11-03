import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminServiceException implements Exception {
  const AdminServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AdminService {
  AdminService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'me-central1');

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<void> _ensureSuperAdmin() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw const AdminServiceException('سجّل الدخول بحساب الإدارة أولاً.');
    }

    try {
      final token = await currentUser.getIdTokenResult();
      if (token.claims?['admin'] != true ||
          token.claims?['superadmin'] != true) {
        throw const AdminServiceException(
          'هذه العملية متاحة لحسابات الإدارة العليا فقط.',
        );
      }
    } on FirebaseAuthException {
      throw const AdminServiceException(
        'تعذر التحقق من صلاحيات الحساب. أعد تسجيل الدخول.',
      );
    }
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchOwners() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'owner')
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchAllBookings() {
    return _firestore.collection('bookings').snapshots().map(
          (snapshot) => snapshot.docs,
        );
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchAdminLogs({
    int limit = 100,
  }) {
    return _firestore
        .collection('admin_logs')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Future<Map<String, dynamic>> activateSubscription({
    required String ownerId,
    required int durationDays,
  }) async {
    await _ensureSuperAdmin();
    if (![30, 60, 90].contains(durationDays)) {
      throw const AdminServiceException('مدة الاشتراك المحددة غير صالحة.');
    }

    try {
      final callable = _functions.httpsCallable('activateOwnerSubscription');
      final response = await callable.call({
        'ownerId': ownerId,
        'durationDays': durationDays,
      });
      final result = Map<String, dynamic>.from(response.data as Map);
      if (result['ownerId'] != ownerId ||
          result['subscriptionId'] is! String ||
          result['expiresAt'] is! String) {
        throw const AdminServiceException(
          'استجابة تفعيل الاشتراك من الخادم غير مكتملة.',
        );
      }
      return result;
    } on AdminServiceException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw AdminServiceException(_callableError(error));
    } on FirebaseException catch (error) {
      throw AdminServiceException(_firestoreError(error.code));
    } on TypeError {
      throw const AdminServiceException(
        'استجابة تفعيل الاشتراك من الخادم غير صالحة.',
      );
    }
  }

  Future<void> deleteOwnerAccount(String ownerId) async {
    await _ensureSuperAdmin();
    try {
      await _functions.httpsCallable('deleteOwnerAccount').call({
        'ownerId': ownerId,
      });
    } on FirebaseFunctionsException catch (error) {
      throw AdminServiceException(_callableError(error));
    } on FirebaseException catch (error) {
      throw AdminServiceException(_firestoreError(error.code));
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getBookings({
    required String field,
    required dynamic value,
  }) async {
    await _ensureSuperAdmin();
    try {
      final snapshot = await _firestore
          .collection('bookings')
          .where(field, isEqualTo: value)
          .get();
      return snapshot.docs;
    } on FirebaseException catch (error) {
      throw AdminServiceException(_firestoreError(error.code));
    }
  }

  String _callableError(FirebaseFunctionsException error) {
    if (error.message != null && error.message!.trim().isNotEmpty) {
      return error.message!;
    }
    return switch (error.code) {
      'unauthenticated' => 'انتهت جلسة الدخول. أعد تسجيل الدخول.',
      'permission-denied' => 'ليست لديك صلاحية تنفيذ هذا الإجراء.',
      'not-found' => 'لم يُعثر على الحساب المطلوب.',
      'invalid-argument' => 'البيانات المرسلة غير صالحة.',
      'resource-exhausted' => 'تجاوزت العملية الحد المسموح به من البيانات.',
      'unavailable' => 'الخدمة غير متاحة حالياً. تحقق من اتصالك.',
      'internal' => 'تعذر إكمال العملية. تحقق من سجل الإدارة.',
      _ => 'تعذر تنفيذ طلب الإدارة. يرجى المحاولة مجدداً.',
    };
  }

  String _firestoreError(String code) {
    return switch (code) {
      'permission-denied' => 'ليست لديك صلاحية الوصول إلى بيانات الإدارة.',
      'unavailable' => 'الخدمة غير متاحة حالياً. تحقق من اتصالك.',
      'failed-precondition' =>
        'تعذر تنفيذ الاستعلام؛ قد يتطلب الأمر إنشاء فهرس Firestore.',
      _ => 'تعذر تحميل بيانات الإدارة. يرجى المحاولة مجدداً.',
    };
  }
}
