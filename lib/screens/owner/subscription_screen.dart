import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/core/constants.dart';
import 'package:fattball/models/subscription_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/services/auth_service.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/screens/owner/owner_bookings.dart';
import 'package:fattball/widgets/responsive_scaffold.dart';
import 'package:fattball/widgets/sports_loading.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;
import 'package:url_launcher/url_launcher.dart';

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
  bool _isSigningOut = false;
  static const int _minimumSubscriptionMonths = 1;
  static const int _maximumSubscriptionMonths = 12;

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

  String _subscriptionDurationLabel(int months) {
    return switch (months) {
      1 => 'شهر واحد',
      2 => 'شهران',
      >= 3 && <= 10 => '$months أشهر',
      _ => '$months شهراً',
    };
  }

  String _whatsAppMessage(int months) {
    return 'مرحباً، أريد تفعيل اشتراك ملعبي في تطبيق Fattball.\n'
        'المدة المختارة: ${_subscriptionDurationLabel(months)}\n'
        'أرجو إرسال باركود شام كاش لإتمام عملية الدفع.\n'
        'شكراً لكم.';
  }

  Future<void> _showRenewalDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var selectedMonths = _minimumSubscriptionMonths;
        var isOpeningWhatsApp = false;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('تجديد الاشتراك'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'لتفعيل اشتراكك، يرجى التواصل معنا عبر واتساب لإرسال '
                  'باركود شام كاش. سيتم تفعيل اشتراكك فوراً بعد تأكيد الدفع.',
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<int>(
                  value: selectedMonths,
                  decoration: const InputDecoration(
                    labelText: 'مدة الاشتراك',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  items: [
                    for (var months = _minimumSubscriptionMonths;
                        months <= _maximumSubscriptionMonths;
                        months++)
                      DropdownMenuItem(
                        value: months,
                        child: Text(_subscriptionDurationLabel(months)),
                      ),
                  ],
                  onChanged: isOpeningWhatsApp
                      ? null
                      : (months) {
                          if (months == null) return;
                          setDialogState(() => selectedMonths = months);
                        },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isOpeningWhatsApp
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('إغلاق'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                ),
                onPressed: isOpeningWhatsApp
                    ? null
                    : () async {
                        setDialogState(() => isOpeningWhatsApp = true);
                        final message = _whatsAppMessage(selectedMonths);
                        final uri = Uri.parse(
                          'https://wa.me/963981359229'
                          '?text=${Uri.encodeComponent(message)}',
                        );

                        try {
                          final launched = await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                          if (!launched && mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              glassSnackBar(
                                content: const Text(
                                  'تعذر فتح واتساب. تحقق من تثبيت التطبيق '
                                  'أو أعد المحاولة.',
                                ),
                              ),
                            );
                          }
                        } on PlatformException {
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              glassSnackBar(
                                content: const Text(
                                  'تعذر فتح واتساب على هذا الجهاز.',
                                ),
                              ),
                            );
                          }
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() => isOpeningWhatsApp = false);
                          }
                        }
                      },
                icon: isOpeningWhatsApp
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.chat_rounded),
                label: Text(
                  isOpeningWhatsApp ? 'جارٍ فتح واتساب...' : 'تواصل عبر واتساب',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    try {
      await ref.read(authServiceProvider).signOut();
    } on AuthServiceException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          glassSnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
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
          onPressed: _isSigningOut ? null : _signOut,
          icon: _isSigningOut
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout),
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
                          onPressed: _showRenewalDialog,
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
                    return const SportsEmptyState(
                      title: 'لا يوجد سجل اشتراكات بعد',
                      message: 'ستظهر تفاصيل اشتراكاتك هنا بعد تفعيلها.',
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
