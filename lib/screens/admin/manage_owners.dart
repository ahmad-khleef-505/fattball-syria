import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/screens/admin/activate_subscription.dart';
import 'package:fattball/services/admin_service.dart';
import 'package:fattball/screens/admin/manage_bookings.dart';
import 'package:fattball/widgets/responsive_scaffold.dart';
import 'package:fattball/widgets/sports_loading.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ManageOwnersScreen extends ConsumerStatefulWidget {
  const ManageOwnersScreen({super.key});

  @override
  ConsumerState<ManageOwnersScreen> createState() => _ManageOwnersScreenState();
}

class _ManageOwnersScreenState extends ConsumerState<ManageOwnersScreen> {
  String _searchTerm = '';
  final Set<String> _deletingOwnerIds = {};

  Future<void> _deleteOwner(UserModel owner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف حساب صاحب الملعب'),
        content: Text(
          'سيُحذف حساب ${owner.name} وجميع ملاعبه وحجوزاته واشتراكاته '
          'نهائياً. لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingOwnerIds.add(owner.uid));
    try {
      await ref.read(adminServiceProvider).deleteOwnerAccount(owner.uid);
      if (mounted) _showMessage('تم حذف الحساب والبيانات المرتبطة به.');
    } on AdminServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _deletingOwnerIds.remove(owner.uid));
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(glassSnackBar(content: Text(message)));
  }

  String _readError(Object? error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => 'لا تملك صلاحية عرض أصحاب الملاعب.',
        'unavailable' => 'الخدمة غير متاحة حالياً. تحقق من اتصالك.',
        _ => 'تعذر تحميل أصحاب الملاعب. يرجى المحاولة مجدداً.',
      };
    }
    return 'تعذر تحميل أصحاب الملاعب. يرجى المحاولة مجدداً.';
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: 'إدارة أصحاب الملاعب',
      destinations: const [
        ResponsiveDestination(
          label: 'الرئيسية',
          icon: Icons.dashboard_outlined,
        ),
        ResponsiveDestination(
          label: 'أصحاب الملاعب',
          icon: Icons.storefront_outlined,
          selectedIcon: Icons.storefront,
        ),
        ResponsiveDestination(
          label: 'الحجوزات',
          icon: Icons.event_note_outlined,
        ),
      ],
      selectedIndex: 1,
      onDestinationSelected: (index) {
        if (index == 0) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else if (index == 2) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ManageBookingsScreen(),
            ),
          );
        }
      },
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'بحث بالاسم أو البريد أو الهاتف',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _searchTerm = value.trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: ref.read(adminServiceProvider).watchOwners(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _readError(snapshot.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final owners = <UserModel>[];
                for (final document in snapshot.data ?? []) {
                  try {
                    owners.add(
                      UserModel.fromMap(
                        document.id,
                        document.data(),
                      ),
                    );
                  } on FormatException {
                    return const Center(
                      child: Text('تعذر قراءة بيانات أحد أصحاب الملاعب.'),
                    );
                  } on TypeError {
                    return const Center(
                      child: Text('بيانات أحد أصحاب الملاعب غير مكتملة.'),
                    );
                  }
                }
                owners.sort(
                  (a, b) => a.name.toLowerCase().compareTo(
                        b.name.toLowerCase(),
                      ),
                );
                final query = _searchTerm.toLowerCase();
                final filtered = owners.where((owner) {
                  return owner.name.toLowerCase().contains(query) ||
                      owner.email.toLowerCase().contains(query) ||
                      (owner.phone?.toLowerCase().contains(query) ?? false);
                }).toList();

                if (filtered.isEmpty) {
                  return SportsEmptyState(
                    title: query.isEmpty
                        ? 'لا يوجد أصحاب ملاعب مسجلون'
                        : 'لا توجد نتائج مطابقة',
                    message: query.isEmpty
                        ? 'ستظهر هنا حسابات أصحاب الملاعب المسجلة.'
                        : 'جرّب البحث باسم أو بريد إلكتروني آخر.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final owner = filtered[index];
                    return _OwnerCard(
                      owner: owner,
                      isDeleting: _deletingOwnerIds.contains(owner.uid),
                      onActivate: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ActivateSubscriptionScreen(
                            owner: owner,
                          ),
                        ),
                      ),
                      onDelete: () => _deleteOwner(owner),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({
    required this.owner,
    required this.isDeleting,
    required this.onActivate,
    required this.onDelete,
  });

  final UserModel owner;
  final bool isDeleting;
  final VoidCallback onActivate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final expiry = owner.subscriptionExpiry;
    final active =
        owner.isActive && expiry != null && expiry.isAfter(DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(owner.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(owner.email, textDirection: TextDirection.ltr),
            if (owner.phone != null) Text(owner.phone!),
            const SizedBox(height: 6),
            Text(
              active
                  ? 'الاشتراك فعال حتى ${_formatDate(expiry)}'
                  : 'الاشتراك غير فعال',
              style: TextStyle(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onActivate,
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: Text(active ? 'تمديد الاشتراك' : 'تفعيل الاشتراك'),
                ),
                OutlinedButton.icon(
                  onPressed: isDeleting ? null : onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  label: const Text('حذف الحساب'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
