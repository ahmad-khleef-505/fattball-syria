import 'package:cloud_firestore/cloud_firestore.dart';
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
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

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
    if (![30, 60, 90, 180, 365].contains(durationDays)) {
      throw const AdminServiceException('مدة الاشتراك المحددة غير صالحة.');
    }

    try {
      final now = DateTime.now();
      final userRef = _firestore.collection('users').doc(ownerId);
      final userSnapshot = await userRef.get();
      
      if (!userSnapshot.exists) {
        throw const AdminServiceException('لم يتم العثور على حساب صاحب الملعب.');
      }

      // حساب تاريخ الانتهاء (بناءً على الاشتراك الحالي إن وجد)
      final currentExpiry = userSnapshot.data()?['subscriptionExpiry'] as Timestamp?;
      DateTime baseDate = now;
      if (currentExpiry != null && currentExpiry.toDate().isAfter(now)) {
        baseDate = currentExpiry.toDate();
      }
      final newExpiry = baseDate.add(Duration(days: durationDays));

      final batch = _firestore.batch();

      // 1. تحديث حساب المالك
      batch.update(userRef, {
        'isActive': true,
        'subscriptionExpiry': Timestamp.fromDate(newExpiry),
      });

      // 2. تحديث جميع ملاعب المالك
      final fieldsSnapshot = await _firestore.collection('fields').where('ownerId', isEqualTo: ownerId).get();
      for (var doc in fieldsSnapshot.docs) {
        batch.update(doc.reference, {
          'isActive': true,
          'ownerSubscriptionExpiry': Timestamp.fromDate(newExpiry),
        });
      }

      // 3. تسجيل العملية في سجل الأدمن
      final logRef = _firestore.collection('admin_logs').doc();
      batch.set(logRef, {
        'adminUid': _auth.currentUser?.uid,
        'action': 'تفعيل اشتراك يدوي',
        'targetUid': ownerId,
        'durationDays': durationDays,
        'newExpiry': Timestamp.fromDate(newExpiry),
        'createdAt': Timestamp.fromDate(now),
      });

      await batch.commit();

      return {
        'ownerId': ownerId,
        'subscriptionId': logRef.id,
        'expiresAt': newExpiry.toIso8601String(),
      };
      
    } on AdminServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw AdminServiceException(_firestoreError(error.code));
    }
  }

  Future<void> deleteOwnerAccount(String ownerId) async {
    await _ensureSuperAdmin();
    try {
      final batch = _firestore.batch();
      
      // 1. حذف حساب المستخدم
      batch.delete(_firestore.collection('users').doc(ownerId));

      // 2. حذف جميع الملاعب
      final fields = await _firestore.collection('fields').where('ownerId', isEqualTo: ownerId).get();
      for (var doc in fields.docs) {
        batch.delete(doc.reference);
      }

      // 3. حذف جميع الحجوزات
      final bookings = await _firestore.collection('bookings').where('ownerId', isEqualTo: ownerId).get();
      for (var doc in bookings.docs) {
        batch.delete(doc.reference);
      }

      // 4. حذف أوقات الصيانة
      final maintenance = await _firestore.collection('field_maintenance').where('ownerId', isEqualTo: ownerId).get();
      for (var doc in maintenance.docs) {
        batch.delete(doc.reference);
      }

      // 5. حذف أقفال المواعيد
      final locks = await _firestore.collection('booking_locks').where('ownerId', isEqualTo: ownerId).get();
      for (var doc in locks.docs) {
        batch.delete(doc.reference);
      }

      // تنفيذ الحذف دفعة واحدة
      await batch.commit();

      // 6. تسجيل عملية الحذف
      await _firestore.collection('admin_logs').add({
        'adminUid': _auth.currentUser?.uid,
        'action': 'حذف حساب صاحب ملعب نهائياً',
        'targetUid': ownerId,
        'createdAt': Timestamp.now(),
      });

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