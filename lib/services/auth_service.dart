import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;

  Stream<UserModel?> get userStream {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;

      try {
        final snapshot =
            await _firestore.collection('users').doc(user.uid).get();
        final data = snapshot.data();
        if (data == null) {
          throw const AuthServiceException(
            'لم يُعثر على ملف المستخدم. يرجى التواصل مع الدعم.',
          );
        }
        return UserModel.fromMap(user.uid, data);
      } on FirebaseException catch (error) {
        throw AuthServiceException(_firestoreErrorMessage(error.code));
      } on FormatException {
        throw const AuthServiceException(
          'بيانات حسابك غير مكتملة أو غير صالحة.',
        );
      }
    });
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) async {
    if (role != 'owner' && role != 'customer') {
      throw const AuthServiceException('نوع الحساب المحدد غير صالح.');
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthServiceException('تعذر إنشاء حساب المستخدم.');
      }

      final normalizedPhone = phone?.trim();
      final profile = UserModel(
        uid: user.uid,
        name: name.trim(),
        email: email.trim(),
        role: role,
        phone: normalizedPhone == null || normalizedPhone.isEmpty
            ? null
            : normalizedPhone,
        createdAt: DateTime.now(),
        isActive: true,
      );

      try {
        await _firestore.collection('users').doc(user.uid).set(profile.toMap());
      } on FirebaseException catch (error) {
        try {
          await user.delete();
        } on FirebaseAuthException {
          throw AuthServiceException(
            '${_firestoreErrorMessage(error.code)} '
            'تعذر التراجع عن إنشاء حساب المصادقة؛ يرجى المحاولة لاحقاً أو '
            'التواصل مع الدعم.',
          );
        }
        throw AuthServiceException(_firestoreErrorMessage(error.code));
      }
    } on AuthServiceException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_authErrorMessage(error.code));
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_authErrorMessage(error.code));
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_authErrorMessage(error.code));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_authErrorMessage(error.code));
    }
  }

  String _authErrorMessage(String code) {
    return switch (code) {
      'invalid-email' => 'صيغة البريد الإلكتروني غير صحيحة.',
      'user-disabled' => 'تم إيقاف هذا الحساب.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
      'email-already-in-use' => 'هذا البريد الإلكتروني مسجل مسبقاً.',
      'weak-password' => 'كلمة المرور ضعيفة؛ استخدم 6 محارف على الأقل.',
      'operation-not-allowed' => 'طريقة تسجيل الدخول هذه غير مفعّلة حالياً.',
      'too-many-requests' => 'محاولات كثيرة. يرجى الانتظار ثم المحاولة مجدداً.',
      'network-request-failed' => 'تعذر الاتصال بالإنترنت. تحقق من اتصالك.',
      'requires-recent-login' =>
        'انتهت صلاحية الجلسة؛ سجل الدخول مجدداً ثم أعد المحاولة.',
      _ => 'تعذر إكمال طلب المصادقة. يرجى المحاولة مجدداً.',
    };
  }

  String _firestoreErrorMessage(String code) {
    return switch (code) {
      'permission-denied' => 'ليست لديك صلاحية الوصول إلى بيانات الحساب.',
      'unavailable' => 'الخدمة غير متاحة حالياً. تحقق من اتصالك وحاول مجدداً.',
      'not-found' => 'لم يُعثر على بيانات الحساب المطلوبة.',
      _ => 'تعذر حفظ أو تحميل بيانات الحساب. يرجى المحاولة مجدداً.',
    };
  }
}
