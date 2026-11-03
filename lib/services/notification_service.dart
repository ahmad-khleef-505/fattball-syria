import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationServiceException implements Exception {
  const NotificationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AudioPlayer? soundPlayer,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _soundPlayer = soundPlayer ?? AudioPlayer();

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AudioPlayer _soundPlayer;

  Stream<RemoteMessage> get foregroundMessages => _supportsMessaging
      ? FirebaseMessaging.onMessage
      : const Stream<RemoteMessage>.empty();

  bool get _supportsMessaging =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  String? _activeUid;
  StreamSubscription<String>? _tokenSubscription;

  Future<void> synchronizeUser(String? uid) async {
    if (_activeUid == uid) return;

    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    _activeUid = uid;

    if (uid == null || !_supportsMessaging) {
      return;
    }

    try {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (_auth.currentUser?.uid != uid) return;

      final isAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!isAuthorized) {
        await _saveToken(uid, null);
        return;
      }

      _tokenSubscription = _messaging.onTokenRefresh.listen(
        (token) => _saveRefreshedToken(uid, token),
        onError: (Object error, StackTrace stackTrace) {
          developer.log(
            'FCM token refresh stream failed.',
            name: 'fattball.notifications',
            error: error,
            stackTrace: stackTrace,
          );
        },
      );

      final token = await _messaging.getToken();
      await _saveToken(uid, token);
    } on NotificationServiceException {
      _activeUid = null;
      rethrow;
    } on FirebaseException catch (error) {
      _activeUid = null;
      throw NotificationServiceException(_firebaseError(error.code));
    } catch (error, stackTrace) {
      _activeUid = null;
      developer.log(
        'FCM registration failed.',
        name: 'fattball.notifications',
        error: error,
        stackTrace: stackTrace,
      );
      throw const NotificationServiceException(
        'تعذر تفعيل إشعارات هذا الجهاز. يمكنك إعادة المحاولة لاحقاً.',
      );
    }
  }

  Future<void> stopListening() async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    _activeUid = null;
  }

  Future<void> playSportsNotificationSound() async {
    try {
      await _soundPlayer.play(
        AssetSource('sounds/football_whistle.wav'),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Could not play the booking notification sound.',
        name: 'fattball.notifications',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> dispose() async {
    await stopListening();
    await _soundPlayer.dispose();
  }

  Future<void> _saveRefreshedToken(String uid, String token) async {
    try {
      await _saveToken(uid, token);
    } on NotificationServiceException catch (error, stackTrace) {
      developer.log(
        error.message,
        name: 'fattball.notifications',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _saveToken(String uid, String? token) async {
    if (_auth.currentUser?.uid != uid) return;

    try {
      await _firestore.collection('users').doc(uid).update({
        'fcmToken': token,
      });
    } on FirebaseException catch (error) {
      throw NotificationServiceException(_firebaseError(error.code));
    }
  }

  String _firebaseError(String code) {
    return switch (code) {
      'permission-denied' => 'لا توجد صلاحية لحفظ رمز الإشعارات.',
      'unavailable' => 'الخدمة غير متاحة حالياً. تحقق من اتصالك.',
      'not-found' => 'تعذر العثور على ملف حسابك لحفظ إعدادات الإشعارات.',
      _ => 'تعذر تسجيل الإشعارات. يرجى التحقق من إعداد Firebase.',
    };
  }
}
