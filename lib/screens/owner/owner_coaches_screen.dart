import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/coach_model.dart';
import 'package:fattball/models/field_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/services/coach_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

class OwnerCoachesScreen extends ConsumerWidget {
  const OwnerCoachesScreen({
    super.key,
    required this.field,
    required this.owner,
  });

  final FieldModel field;
  final UserModel owner;

  Future<void> _addCoach(BuildContext context, WidgetRef ref) async {
    final draft = await showDialog<_CoachDraft>(
      context: context,
      builder: (_) => const _CoachFormDialog(),
    );
    if (draft == null || !context.mounted) return;

    try {
      await ref.read(coachServiceProvider).createCoach(
            fieldId: field.fieldId,
            ownerId: owner.uid,
            name: draft.name,
            specialty: draft.specialty,
            bio: draft.bio,
            pricePerHour: draft.pricePerHour,
          );
      if (context.mounted) {
        _showMessage(context, 'تمت إضافة المدرب إلى ${field.name}.');
      }
    } on CoachServiceException catch (error) {
      if (context.mounted) _showMessage(context, error.message);
    }
  }

  Future<void> _deleteCoach(
    BuildContext context,
    WidgetRef ref,
    CoachModel coach,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المدرب'),
        content: Text(
          'سيُزال ${coach.name} من قائمة المدربين المتاحين. '
          'لن تتأثر بيانات جلسات التدريب السابقة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(coachServiceProvider).deleteCoach(
            fieldId: field.fieldId,
            ownerId: owner.uid,
            coachId: coach.coachId,
          );
    } on CoachServiceException catch (error) {
      if (context.mounted) _showMessage(context, error.message);
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('مدربو ${field.name}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCoach(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('إضافة مدرب'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: ref
                .watch(coachServiceProvider)
                .watchCoaches(field.fieldId, activeOnly: false),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'تعذر تحميل قائمة المدربين. تحقق من صلاحيات Firebase واتصالك.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final coaches = <CoachModel>[];
              try {
                for (final document in snapshot.data?.docs ?? []) {
                  coaches.add(CoachModel.fromMap(document.id, document.data()));
                }
              } on FormatException catch (error) {
                return Center(child: Text(error.message));
              } on TypeError {
                return const Center(
                  child: Text('بيانات أحد المدربين غير مكتملة.'),
                );
              }

              if (coaches.isEmpty) {
                return const _CoachEmptyState(
                  title: 'لا يوجد مدربون لهذا الملعب بعد',
                  message: 'أضف مدرباً وحدد اختصاصه وأجره لتبدأ بحجز الجلسات.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: coaches.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final coach = coaches[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                child: Text(
                                  coach.name.substring(0, 1),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      coach.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(coach.specialty),
                                  ],
                                ),
                              ),
                              Switch(
                                value: coach.isActive,
                                onChanged: (value) async {
                                  try {
                                    await ref
                                        .read(coachServiceProvider)
                                        .setCoachActive(
                                          fieldId: field.fieldId,
                                          ownerId: owner.uid,
                                          coachId: coach.coachId,
                                          isActive: value,
                                        );
                                  } on CoachServiceException catch (error) {
                                    if (context.mounted) {
                                      _showMessage(context, error.message);
                                    }
                                  }
                                },
                              ),
                              IconButton(
                                tooltip: 'حذف المدرب',
                                onPressed: () =>
                                    _deleteCoach(context, ref, coach),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          if (coach.bio.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(coach.bio),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            '${coach.pricePerHour.toStringAsFixed(2)} USD / ساعة تدريب',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CoachEmptyState extends StatelessWidget {
  const _CoachEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _CoachDraft {
  const _CoachDraft({
    required this.name,
    required this.specialty,
    required this.bio,
    required this.pricePerHour,
  });

  final String name;
  final String specialty;
  final String bio;
  final double pricePerHour;
}

class _CoachFormDialog extends StatefulWidget {
  const _CoachFormDialog();

  @override
  State<_CoachFormDialog> createState() => _CoachFormDialogState();
}

class _CoachFormDialogState extends State<_CoachFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _bioController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _specialtyController.dispose();
    _bioController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String? _requiredText(String? value, String label, int maxLength) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'أدخل $label.';
    if (text.length > maxLength) return 'الحد الأقصى $maxLength محرفاً.';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _CoachDraft(
        name: _nameController.text.trim(),
        specialty: _specialtyController.text.trim(),
        bio: _bioController.text.trim(),
        pricePerHour: double.parse(_priceController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة مدرب'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'اسم المدرب'),
                validator: (value) {
                  final error = _requiredText(value, 'اسم المدرب', 80);
                  if (error != null) return error;
                  if (value!.trim().length < 2) {
                    return 'اسم المدرب قصير جداً.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _specialtyController,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'الاختصاص',
                  hintText: 'تدريب ناشئين، حراس مرمى...',
                ),
                validator: (value) => _requiredText(value, 'الاختصاص', 80),
              ),
              TextFormField(
                controller: _bioController,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'نبذة وخبرة (اختياري)',
                ),
              ),
              TextFormField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'أجر التدريب للساعة (USD)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) {
                  final price = double.tryParse(value?.trim() ?? '');
                  if (price == null ||
                      !price.isFinite ||
                      price <= 0 ||
                      price > 10000) {
                    return 'أدخل أجراً أكبر من صفر ولا يتجاوز 10000.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('حفظ المدرب'),
        ),
      ],
    );
  }
}
