import 'package:fattball/models/field_model.dart';
import 'package:fattball/models/promo_code_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/services/promo_code_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class OwnerPromoCodesScreen extends ConsumerStatefulWidget {
  const OwnerPromoCodesScreen({
    super.key,
    required this.owner,
    required this.field,
  });

  final UserModel owner;
  final FieldModel field;

  @override
  ConsumerState<OwnerPromoCodesScreen> createState() =>
      _OwnerPromoCodesScreenState();
}

class _OwnerPromoCodesScreenState extends ConsumerState<OwnerPromoCodesScreen> {
  final _codeController = TextEditingController();
  final _percentController = TextEditingController(text: '10');
  DateTime? _expiresAt;
  bool _isSaving = false;
  final Set<String> _deletingCodes = {};

  @override
  void dispose() {
    _codeController.dispose();
    _percentController.dispose();
    super.dispose();
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _selectExpiry() async {
    final now = DateTime.now();
    final initial = _expiresAt ?? now.add(const Duration(days: 7));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day + 1),
      lastDate: DateTime(now.year + 3),
      helpText: 'اختر آخر يوم لصلاحية الكود',
    );
    if (date == null || !mounted) return;
    setState(() {
      _expiresAt = DateTime(
        date.year,
        date.month,
        date.day,
        23,
        59,
        59,
      );
    });
  }

  Future<void> _createCode() async {
    final code = PromoCodeService.normalizeCode(_codeController.text);
    final percent = int.tryParse(_percentController.text);
    final expiry = _expiresAt;
    if (!RegExp(r'^[A-Z0-9]{4,20}$').hasMatch(code)) {
      _message('استخدم 4 إلى 20 حرفاً إنجليزياً أو رقماً للكود.');
      return;
    }
    if (percent == null || percent < 1 || percent > 90) {
      _message('أدخل نسبة خصم بين 1% و90%.');
      return;
    }
    if (expiry == null) {
      _message('اختر تاريخ انتهاء صلاحية الكود.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(promoCodeServiceProvider).createPromoCode(
            field: widget.field,
            ownerId: widget.owner.uid,
            code: code,
            discountPercent: percent,
            expiresAt: expiry,
          );
      _codeController.clear();
      _message('تم إنشاء كود الخصم $code بنجاح.');
    } on PromoCodeServiceException catch (error) {
      _message(error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteCode(PromoCodeModel promo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف كود الخصم'),
        content: Text('هل تريد حذف الكود ${promo.code}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deletingCodes.add(promo.code));
    try {
      await ref.read(promoCodeServiceProvider).deletePromoCode(
            fieldId: widget.field.fieldId,
            ownerId: widget.owner.uid,
            code: promo.code,
          );
      _message('تم حذف الكود ${promo.code}.');
    } on PromoCodeServiceException catch (error) {
      _message(error.message);
    } finally {
      if (mounted) setState(() => _deletingCodes.remove(promo.code));
    }
  }

  String _date(DateTime value) => DateFormat('yyyy/MM/dd').format(value);

  @override
  Widget build(BuildContext context) {
    final promosAsync =
        ref.watch(ownerPromoCodesProvider(widget.field.fieldId));

    return Scaffold(
      appBar: AppBar(title: Text('خصومات ${widget.field.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'إنشاء كود جديد',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    textAlign: TextAlign.left,
                    maxLength: 20,
                    decoration: const InputDecoration(
                      labelText: 'كود الخصم',
                      hintText: 'FOOTBALL10',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _percentController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'نسبة الخصم',
                      suffixText: '%',
                      prefixIcon: Icon(Icons.percent),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _selectExpiry,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _expiresAt == null
                          ? 'تحديد تاريخ الانتهاء'
                          : 'ينتهي في ${_date(_expiresAt!)}',
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _createCode,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    label: const Text('إنشاء الكود'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'أكواد هذا الملعب',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          promosAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => const _PromoMessage(
              message: 'تعذر تحميل أكواد الخصم. تحقق من الصلاحيات والاتصال.',
              icon: Icons.error_outline,
            ),
            data: (promos) {
              if (promos.isEmpty) {
                return const _PromoMessage(
                  message: 'لم تنشئ أكواد خصم لهذا الملعب بعد.',
                  icon: Icons.local_offer_outlined,
                );
              }
              return Column(
                children: [
                  for (final promo in promos)
                    _PromoCodeTile(
                      promo: promo,
                      isDeleting: _deletingCodes.contains(promo.code),
                      dateLabel: _date(promo.expiresAt),
                      onDelete: () => _deleteCode(promo),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PromoCodeTile extends StatelessWidget {
  const _PromoCodeTile({
    required this.promo,
    required this.isDeleting,
    required this.dateLabel,
    required this.onDelete,
  });

  final PromoCodeModel promo;
  final bool isDeleting;
  final String dateLabel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final expired = !promo.isValidAt(DateTime.now());
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          Icons.local_offer_outlined,
          color: expired
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : Theme.of(context).colorScheme.tertiary,
        ),
        title: Text(
          promo.code,
          textAlign: TextAlign.left,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${promo.discountPercent}% خصم — '
          '${expired ? 'منتهي أو غير فعال' : 'ينتهي $dateLabel'}',
        ),
        trailing: IconButton(
          tooltip: 'حذف الكود',
          onPressed: isDeleting ? null : onDelete,
          icon: isDeleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline),
        ),
      ),
    );
  }
}

class _PromoMessage extends StatelessWidget {
  const _PromoMessage({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
