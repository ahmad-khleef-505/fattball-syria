import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/core/constants.dart';
import 'package:fattball/core/firebase_options.dart';
import 'package:fattball/core/theme.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/providers/theme_provider.dart';
import 'package:fattball/screens/admin/admin_dashboard.dart';
import 'package:fattball/screens/customer/home_map.dart';
import 'package:fattball/screens/auth/login_screen.dart';
import 'package:fattball/screens/auth/register_screen.dart';
import 'package:fattball/screens/owner/owner_dashboard.dart';
import 'package:fattball/services/auth_service.dart';
import 'package:fattball/services/notification_service.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  runApp(const ProviderScope(child: FattballApp()));
}

class FattballApp extends ConsumerWidget {
  const FattballApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode, 
      builder: (context, child) {
        return Directionality(
          textDirection: AppTheme.textDirection,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _AppVersionChecker(), // 🚀 نبدأ بفحص الإصدار أولاً
    );
  }
}

// 🚀 شاشة فحص الإصدار
class _AppVersionChecker extends StatefulWidget {
  const _AppVersionChecker();

  @override
  State<_AppVersionChecker> createState() => _AppVersionCheckerState();
}

class _AppVersionCheckerState extends State<_AppVersionChecker> {
  bool _isChecking = true;
  bool _needsUpdate = false;

  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // مثال: "1.0.0"

      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('version')
          .get();

      if (doc.exists) {
        final minVersion = doc.data()?['min_version'] ?? '1.0.0';
        // مقارنة الإصدارات
        if (_compareVersions(currentVersion, minVersion) < 0) {
          if (mounted) setState(() => _needsUpdate = true);
        }
      }
    } catch (e) {
      // في حال حدوث خطأ، نكمل التطبيق طبيعياً لتجنب حظر المستخدم
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  // دالة لمقارنة الإصدارات (مثل 1.0.1 و 1.0.0)
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();
    for (var i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_needsUpdate) {
      return const _UpdateRequiredScreen();
    }

    // إذا كان الإصدار حديثاً، ننتقل للشاشة الطبيعية
    return const _StartupScreen();
  }
}

// 🚀 شاشة التحديث الإجباري
class _UpdateRequiredScreen extends StatelessWidget {
  const _UpdateRequiredScreen();

  Future<void> _openStore() async {
    // ضع هنا رابط التطبيق على Google Play (أو App Store)
    const url = 'https://play.google.com/store/apps/details?id=com.fattball.syria';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.system_update, size: 80, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'تحديث مطلوب',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'لقد قمنا بإضافة تحسينات وميزات جديدة! يرجى تحديث التطبيق إلى أحدث إصدار للمتابعة.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openStore,
                  icon: const Icon(Icons.download),
                  label: const Text('تحديث الآن'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartupScreen extends ConsumerWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    ref.listen<AsyncValue<UserModel?>>(authStateProvider, (previous, next) {
      final user = next.valueOrNull;
      if (user == null) {
        unawaited(ref.read(notificationServiceProvider).stopListening());
      } else {
        unawaited(_registerNotifications(context, ref, user.uid));
      }
    });
    ref.listen(foregroundMessagesProvider, (previous, next) {
      next.when(
        data: (message) {
          if (!context.mounted) return;
          if (message.data['sound'] == 'football_whistle') {
            unawaited(
              ref
                  .read(notificationServiceProvider)
                  .playSportsNotificationSound(),
            );
          }
          final title = message.notification?.title;
          final body = message.notification?.body;
          final messageText = [title, body]
              .whereType<String>()
              .where((part) => part.trim().isNotEmpty)
              .join('\n');
          if (messageText.isNotEmpty) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(glassSnackBar(content: Text(messageText)));
          }
        },
        error: (error, stackTrace) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            glassSnackBar(
              content: const Text('تعذر استقبال الإشعارات حالياً.'),
            ),
          );
        },
        loading: () {},
      );
    });

    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تعذر تحميل بيانات الحساب.'),
                const SizedBox(height: 8),
                Text(
                  error is AuthServiceException
                      ? error.message
                      : 'يرجى التحقق من إعداد Firebase والاتصال بالإنترنت.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(authStateProvider),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          return LoginScreen(
            onRegister: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RegisterScreen(
                    onLogin: () => Navigator.of(context).pop(),
                  ),
                ),
              );
            },
          );
        }

        if (user.role == 'owner') {
          return OwnerDashboard(user: user);
        }
        if (user.role == 'customer') {
          return HomeMap(user: user);
        }
        if (user.role == 'superadmin') {
          return AdminDashboard(admin: user);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text(AppConstants.appName),
            actions: [
              IconButton(
                tooltip: 'تسجيل الخروج',
                onPressed: () async {
                  try {
                    await ref.read(authServiceProvider).signOut();
                  } on AuthServiceException catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        glassSnackBar(content: Text(error.message)),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: Center(
            child: Text(
              'مرحباً ${user.name}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        );
      },
    );
  }
}

Future<void> _registerNotifications(
  BuildContext context,
  WidgetRef ref,
  String uid,
) async {
  try {
    await ref.read(notificationServiceProvider).synchronizeUser(uid);
  } on NotificationServiceException catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      glassSnackBar(
        content: Text(error.message),
        action: SnackBarAction(
          label: 'إعادة المحاولة',
          onPressed: () => unawaited(_registerNotifications(context, ref, uid)),
        ),
      ),
    );
  }
}