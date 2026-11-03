import 'package:fattball/models/admin_log_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/screens/admin/manage_bookings.dart';
import 'package:fattball/screens/admin/manage_owners.dart';
import 'package:fattball/services/auth_service.dart';
import 'package:fattball/widgets/responsive_scaffold.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key, required this.admin});

  final UserModel admin;

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  late final timezone.Location _damascus;

  @override
  void initState() {
    super.initState();
    timezone_data.initializeTimeZones();
    _damascus = timezone.getLocation('Asia/Damascus');
  }

  String _formatDate(DateTime date) {
    final local = timezone.TZDateTime.from(date, _damascus);
    return '${local.year.toString().padLeft(4, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _logSummary(AdminLogModel log) {
    return switch (log.action) {
      'activate_subscription' => 'تفعيل اشتراك لصاحب ملعب',
      'delete_owner_account' => 'حذف حساب صاحب ملعب',
      'delete_owner_account_failed' => 'تعذر حذف حساب صاحب ملعب',
      'delete_user_account' => 'حذف حساب مستخدم',
      _ => log.action,
    };
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authServiceProvider).signOut();
    } on AuthServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(glassSnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final adminAccess = ref.watch(isSuperAdminProvider);
    return adminAccess.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'تعذر التحقق من صلاحيات الإدارة. أعد تسجيل الدخول.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (isSuperAdmin) {
        if (!isSuperAdmin) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لا تملك صلاحية الوصول إلى لوحة الإدارة العليا.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return ResponsiveScaffold(
          title: 'لوحة الإدارة العليا',
          destinations: const [
            ResponsiveDestination(
              label: 'الرئيسية',
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard,
            ),
            ResponsiveDestination(
              label: 'أصحاب الملاعب',
              icon: Icons.storefront_outlined,
            ),
            ResponsiveDestination(
              label: 'الحجوزات',
              icon: Icons.event_note_outlined,
            ),
          ],
          selectedIndex: 0,
          onDestinationSelected: (index) {
            if (index == 1) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ManageOwnersScreen(),
                ),
              );
            } else if (index == 2) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ManageBookingsScreen(),
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
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.admin_panel_settings_outlined),
                  ),
                  title: Text(widget.admin.name),
                  subtitle: Text(widget.admin.email),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: const Text('إدارة أصحاب الملاعب'),
                  subtitle: const Text('تفعيل الاشتراكات وإدارة الحسابات'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ManageOwnersScreen(),
                    ),
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.event_note_outlined),
                  title: const Text('جميع الحجوزات'),
                  subtitle: const Text('مراجعة حجوزات العملاء والملاعب'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ManageBookingsScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'سجل عمليات الإدارة',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              StreamBuilder(
                stream: ref
                    .read(adminServiceProvider)
                    .watchAdminLogs(limit: 100),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('تعذر تحميل سجل عمليات الإدارة.'),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final documents = snapshot.data ?? [];
                  if (documents.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('لا توجد عمليات إدارية مسجلة.'),
                      ),
                    );
                  }

                  return Column(
                    children: documents.map((document) {
                      try {
                        final log = AdminLogModel.fromMap(
                          document.id,
                          document.data(),
                        );
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.history),
                            title: Text(_logSummary(log)),
                            subtitle: Text(
                              'المستهدف: ${log.targetUid}\n'
                              '${_formatDate(log.createdAt)}',
                            ),
                            isThreeLine: true,
                          ),
                        );
                      } on FormatException {
                        return const Card(
                          child: ListTile(
                            leading: Icon(Icons.error_outline),
                            title: Text('تعذر قراءة سجل إداري.'),
                          ),
                        );
                      } on TypeError {
                        return const Card(
                          child: ListTile(
                            leading: Icon(Icons.error_outline),
                            title: Text('بيانات السجل الإداري غير مكتملة.'),
                          ),
                        );
                      }
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
