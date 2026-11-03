import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/services/auth_service.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.user});

  final UserModel user;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _isSaving = false;
  bool _isSendingReset = false;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String get _roleLabel => switch (widget.user.role) {
        'owner' => 'صاحب ملعب',
        'customer' => 'عميل',
        'superadmin' => 'سوبر أدمن',
        'admin' => 'مدير',
        _ => 'مستخدم',
      };

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.length < 2) {
      _showMessage('يجب أن يتكون الاسم من حرفين على الأقل.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({
        'name': name,
        'phone': phone.isEmpty ? null : phone,
      });
      ref.invalidate(authStateProvider);
      if (mounted) _showMessage('تم تحديث بيانات الملف الشخصي.');
    } on FirebaseException catch (error) {
      if (mounted) {
        _showMessage(
          error.code == 'permission-denied'
              ? 'ليست لديك صلاحية لتحديث هذه البيانات.'
              : 'تعذر حفظ البيانات. تحقق من اتصالك وحاول مجدداً.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    setState(() => _isSendingReset = true);
    try {
      await ref
          .read(authServiceProvider)
          .sendPasswordResetEmail(widget.user.email);
      if (mounted) _showMessage('أرسلنا رابط تغيير كلمة المرور إلى بريدك.');
    } on AuthServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج بالفعل؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('لا'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('نعم'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _signOut();
    }
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await ref.read(authServiceProvider).signOut();
      
      // إغلاق جميع الشاشات والعودة للجذر ليتم توجيه المستخدم لصفحة الدخول تلقائياً
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      
    } on AuthServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(glassSnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = ref.read(authServiceProvider).currentUser?.photoURL;

    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 42,
              backgroundImage:
                  photoUrl == null || photoUrl.isEmpty ? null : NetworkImage(photoUrl),
              child: photoUrl == null || photoUrl.isEmpty
                  ? const Icon(Icons.person_outline, size: 44)
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              widget.user.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'الاسم',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: widget.user.email,
            readOnly: true,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'البريد الإلكتروني',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _roleLabel,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'نوع الحساب',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveProfile,
            icon: _isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? 'جارٍ الحفظ...' : 'حفظ التعديلات'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isSendingReset ? null : _sendPasswordReset,
            icon: _isSendingReset
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_reset_outlined),
            label: Text(
              _isSendingReset
                  ? 'جارٍ إرسال الرابط...'
                  : 'إرسال رابط تغيير كلمة المرور',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: _isSigningOut ? null : _confirmSignOut,
            icon: _isSigningOut
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            label: Text(_isSigningOut ? 'جارٍ تسجيل الخروج...' : 'تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}