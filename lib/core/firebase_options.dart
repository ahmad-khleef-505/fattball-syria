import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// إعدادات مؤقتة؛ استبدلها بالقيم التي يولدها الأمر `flutterfire configure`.
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      TargetPlatform.macOS => macos,
      TargetPlatform.windows => windows,
      TargetPlatform.linux => linux,
      TargetPlatform.fuchsia => throw UnsupportedError(
          'منصة Fuchsia غير مدعومة في إعداد Firebase الحالي.',
        ),
    };
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCKCR64fGc4-lJa1IdtsOqUhd53FT1_QH0',
    appId: '1:938745856147:web:4a9a698e1d91a74ce64d66',
    messagingSenderId: '938745856147',
    projectId: 'fattball-syria',
    authDomain: 'fattball-syria.firebaseapp.com',
    storageBucket: 'fattball-syria.firebasestorage.app',
    measurementId: 'G-STS2C43GDB',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCl2WUx6Z46lzP34wbImMcJY6sMMFjf3G0',
    appId: '1:938745856147:android:2fdff2c038c17252e64d66',
    messagingSenderId: '938745856147',
    projectId: 'fattball-syria',
    storageBucket: 'fattball-syria.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC_9oAwUAY58feGiEuQcyAw8UL8TyGTOwg',
    appId: '1:938745856147:ios:a08d1ef6bcf741abe64d66',
    messagingSenderId: '938745856147',
    projectId: 'fattball-syria',
    storageBucket: 'fattball-syria.firebasestorage.app',
    iosBundleId: 'com.fattball.syria',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FIREBASE_API_KEY',
    appId: 'REPLACE_WITH_FIREBASE_MACOS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_FIREBASE_MESSAGING_SENDER_ID',
    projectId: 'REPLACE_WITH_FIREBASE_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_FIREBASE_STORAGE_BUCKET',
    iosBundleId: 'REPLACE_WITH_MACOS_BUNDLE_ID',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FIREBASE_API_KEY',
    appId: 'REPLACE_WITH_FIREBASE_WINDOWS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_FIREBASE_MESSAGING_SENDER_ID',
    projectId: 'REPLACE_WITH_FIREBASE_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_FIREBASE_STORAGE_BUCKET',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FIREBASE_API_KEY',
    appId: 'REPLACE_WITH_FIREBASE_LINUX_APP_ID',
    messagingSenderId: 'REPLACE_WITH_FIREBASE_MESSAGING_SENDER_ID',
    projectId: 'REPLACE_WITH_FIREBASE_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_FIREBASE_STORAGE_BUCKET',
  );
}
