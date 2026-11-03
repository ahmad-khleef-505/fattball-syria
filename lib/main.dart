import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/core/constants.dart';
import 'package:fattball/core/firebase_options.dart';
import 'package:fattball/core/theme.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/providers/auth_provider.dart';
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

class FattballApp extends StatelessWidget {
  const FattballApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      builder: (context, child) {
        return Directionality(
          textDirection: AppTheme.textDirection,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _StartupScreen(),
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
