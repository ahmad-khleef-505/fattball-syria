import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/core/constants.dart';
import 'package:fattball/models/subscription_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/services/auth_service.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/screens/owner/owner_bookings.dart';
import 'package:fattball/widgets/responsive_scaffold.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class OwnerSubscriptionScreen extends ConsumerStatefulWidget {
  const OwnerSubscriptionScreen({super.key, required this.owner});

  final UserModel owner;

  @override
  ConsumerState<OwnerSubscriptionScreen> createState() =>
      _OwnerSubscriptionScreenState();
}

class _OwnerSubscriptionScreenState
    extends ConsumerState<OwnerSubscriptionScreen> {
  late final timezone.Location _damascus;

  @override
  void initState() {
    super.initState();
    timezone_data.initializeTimeZones();
    _damascus = timezone.getLocation(AppConstants.timeZone);
  }

  String _formatDate(DateTime date) {
    final local = timezone.TZDateTime.from(date, _damascus);
    return '${local.year.toString().padLeft(4, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')}  '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showRenewalPlaceholder() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تجديد الاشتراك'),
        content: const Text(
          'بوابة الدفع غير مربوطة حالياً. لن يتم خصم أي مبلغ أو تفعيل الاشتراك. '
          'سيصبح التجديد متاحاً بعد ربط وسيلة الدفع.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authServiceProvider).signOut();
    } on AuthServiceException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          glassSnackBar(content: Text(error.message)),
        );
      }
    }
  }

  String _errorMessage(Object? error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => 'ليست لديك صلاحية عرض حالة الاشتراك.',
        'unavailable' => 'الخدمة غير متاحة حالياً. تحقق من اتصالك.',
        _ => 'تعذر تحميل بيانات الاشتراك. يرجى المحاولة مجدداً.',
      };
    }
    return 'تعذر تحميل بيانات الاشتراك. يرجى المحاولة مجدداً.';
  }

  @override
  Widget build(BuildContext context) {
    final userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.owner.uid)
        .snapshots();
    final subscriptionsStream = FirebaseFirestore.instance
        .collection('subscriptions')
        .where('ownerId', isEqualTo: widget.owner.uid)
        .snapshots();

    return ResponsiveScaffold(
      title: 'اشتراك الملعب',
      destinations: const [
        ResponsiveDestination(
          label: 'ملاعبك',
          icon: Icons.stadium_outlined,
        ),
        ResponsiveDestination(
          label: 'الحجوزات',
          icon: Icons.event_note_outlined,
        ),
        ResponsiveDestination(
          label: 'الاشتراك',
          icon: Icons.workspace_premium_outlined,
          selectedIcon: Icons.verified,
        ),
      ],
      selectedIndex: 2,
      onDestinationSelected: (index) {
        if (index == 0) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else if (index == 1) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OwnerBookingsScreen(owner: widget.owner),
            ),
          );
        }
      },
      actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
      ],
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userStream,
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage(userSnapshot.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnapshot.data?.data();
          if (userData == null) {
            return const Center(child: Text('تعذر العثور على حساب المالك.'));
          }

          final expiryValue = userData['subscriptionExpiry'];
          if (expiryValue != null && expiryValue is! Timestamp) {
            return const Center(
              child: Text('تاريخ انتهاء الاشتراك المسجل غير صالح.'),
            );
          }
          final expiry = (expiryValue as Timestamp?)?.toDate();
          final accountActive = userData['isActive'] == true;
          final subscriptionActive =
              accountActive && expiry != null && expiry.isAfter(DateTime.now());

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            subscriptionActive
                                ? Icons.verified_outlined
                                : Icons.error_outline,
                            color: subscriptionActive
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              subscriptionActive
                                  ? 'الاشتراك فعال'
                                  : 'الاشتراك غير فعال',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        expiry == null
                            ? 'لم يتم تفعيل اشتراك لهذا الحساب بعد.'
                            : subscriptionActive
                                ? 'ينتهي الاشتراك في ${_formatDate(expiry)}.'
                                : 'انتهى الاشتراك في ${_formatDate(expiry)}.',
                      ),
                      if (!accountActive) ...[
                        const SizedBox(height: 8),
                        Text(
                          'الحساب موقوف حالياً. يرجى التواصل مع الإدارة.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'قيمة الاشتراك الشهري: '
                        '${AppConstants.monthlySubscriptionUsd.toStringAsFixed(0)} '
                        '${AppConstants.currencyCode}',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _showRenewalPlaceholder,
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            'تجديد الاشتراك '
                            '${AppConstants.monthlySubscriptionUsd.toStringAsFixed(0)}\$',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'سجل الاشتراكات',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: subscriptionsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_errorMessage(snapshot.error)),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final subscriptions = <SubscriptionModel>[];
                  for (final document in snapshot.data?.docs ?? []) {
                    try {
                      subscriptions.add(
                        SubscriptionModel.fromMap(
                          document.id,
                          document.data(),
                        ),
                      );
                    } on FormatException {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('تعذر قراءة سجل أحد الاشتراكات.'),
                        ),
                      );
                    } on TypeError {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('بيانات أحد الاشتراكات غير مكتملة.'),
                        ),
                      );
                    }
                  }
                  subscriptions.sort(
                    (a, b) => b.startedAt.compareTo(a.startedAt),
                  );

                  if (subscriptions.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('لا يوجد سجل اشتراكات حتى الآن.'),
                      ),
                    );
                  }

                  return Column(
                    children: subscriptions
                        .map(
                          (subscription) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.receipt_long_outlined),
                              title: Text(
                                '${subscription.amountUsd.toStringAsFixed(0)} '
                                '${AppConstants.currencyCode} — '
                                '${subscription.status}',
                              ),
                              subtitle: Text(
                                'من ${_formatDate(subscription.startedAt)}\n'
                                'إلى ${_formatDate(subscription.expiresAt)}',
                              ),
                              isThreeLine: true,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
