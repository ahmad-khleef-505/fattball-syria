import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/core/constants.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/widgets/responsive_scaffold.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class ActivateSubscriptionScreen extends ConsumerStatefulWidget {
  const ActivateSubscriptionScreen({super.key, required this.owner});

  final UserModel owner;

  @override
  ConsumerState<ActivateSubscriptionScreen> createState() =>
      _ActivateSubscriptionScreenState();
}

class _ActivateSubscriptionScreenState
    extends ConsumerState<ActivateSubscriptionScreen> {
  late final timezone.Location _damascus;
  int _durationDays = 30;
  bool _isSubmitting = false;
  String? _lastExpiry;

  @override
  void initState() {
    super.initState();
    timezone_data.initializeTimeZones();
    _damascus = timezone.getLocation(AppConstants.timeZone);
  }

  String _formatExpiry(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    final local = timezone.TZDateTime.from(date, _damascus);
    return '${local.year.toString().padLeft(4, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _activate() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now();

      final userDoc = await firestore.collection('users').doc(widget.owner.uid).get();
      final currentExpiry = userDoc.data()?['subscriptionExpiry'] as Timestamp?;

      DateTime baseDate = now;
      if (currentExpiry != null && currentExpiry.toDate().isAfter(now)) {
        baseDate = currentExpiry.toDate(); 
      }
      
      // هنا يتم حساب الوقت بدقة (السنة، الشهر، اليوم، الساعة، الدقيقة)
      final newExpiry = baseDate.add(Duration(days: _durationDays));

      await firestore.collection('users').doc(widget.owner.uid).update({
        'isActive': true,
        'subscriptionExpiry': Timestamp.fromDate(newExpiry),
      });

      final fieldsSnapshot = await firestore
          .collection('fields')
          .where('ownerId', isEqualTo: widget.owner.uid)
          .get();

      final batch = firestore.batch();
      for (var doc in fieldsSnapshot.docs) {
        batch.update(doc.reference, {
          'isActive': true,
          'ownerSubscriptionExpiry': Timestamp.fromDate(newExpiry),
        });
      }
      await batch.commit();

      final adminUid = ref.read(authStateProvider).value?.uid;
      await firestore.collection('admin_logs').add({
        'adminUid': adminUid,
        'action': 'تفعيل اشتراك يدوي',
        'targetUid': widget.owner.uid,
        'durationDays': _durationDays,
        'newExpiry': Timestamp.fromDate(newExpiry),
        'createdAt': Timestamp.fromDate(now),
      });

      if (!mounted) return;
      
      setState(() {
        _lastExpiry = newExpiry.toIso8601String();
      });
      _showMessage('تم تفعيل الاشتراك بنجاح حتى ${_formatExpiry(_lastExpiry!)}');
      
    } on FirebaseException catch (error) {
      if (mounted) {
        _showMessage(error.code == 'permission-denied'
            ? 'ليست لديك صلاحية لتفعيل الاشتراك.'
            : 'تعذر تفعيل الاشتراك. تحقق من الاتصال.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(glassSnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final amount = AppConstants.monthlySubscriptionUsd * _durationDays / 30;
    return Scaffold(
      appBar: AppBar(title: const Text('تفعيل اشتراك')),
      body: ResponsiveContent(
        maxWidth: 720,
        padding: EdgeInsets.zero,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.storefront_outlined)),
                title: Text(widget.owner.name),
                subtitle: Text(widget.owner.email, textDirection: TextDirection.ltr),
              ),
            ),
            const SizedBox(height: 20),
            
            // القائمة المنسدلة للمدد الخمسة
            DropdownButtonFormField<int>(
              value: _durationDays,
              decoration: const InputDecoration(
                labelText: 'مدة التفعيل',
                prefixIcon: Icon(Icons.calendar_month_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 30, child: Text('شهر واحد (30 يوماً)')),
                DropdownMenuItem(value: 60, child: Text('شهرين (60 يوماً)')),
                DropdownMenuItem(value: 90, child: Text('3 أشهر (90 يوماً)')),
                DropdownMenuItem(value: 180, child: Text('6 أشهر (180 يوماً)')),
                DropdownMenuItem(value: 365, child: Text('سنة كاملة (365 يوماً)')),
              ],
              onChanged: _isSubmitting
                  ? null
                  : (value) {
                      if (value != null) setState(() => _durationDays = value);
                    },
            ),
            
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: Text('القيمة: ${amount.toStringAsFixed(0)} USD'),
                subtitle: const Text('هذا تفعيل إداري يدوي، ولا يمثل عملية دفع إلكترونية.'),
              ),
            ),
            if (_lastExpiry != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.green.withOpacity(0.1),
                child: ListTile(
                  leading: const Icon(Icons.verified_outlined, color: Colors.green),
                  title: const Text('انتهاء الاشتراك الجديد'),
                  subtitle: Text(_formatExpiry(_lastExpiry!), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _activate,
              icon: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: Text(_isSubmitting ? 'جارٍ التفعيل...' : 'تفعيل / تمديد الاشتراك'),
            ),
          ],
        ),
      ),
    );
  }
}