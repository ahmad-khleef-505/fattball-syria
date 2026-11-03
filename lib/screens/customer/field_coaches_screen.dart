import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/coach_model.dart';
import 'package:fattball/models/field_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/screens/customer/booking_screen.dart';
import 'package:fattball/widgets/sports_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FieldCoachesScreen extends ConsumerWidget {
  const FieldCoachesScreen({
    super.key,
    required this.field,
    required this.customer,
  });

  final FieldModel field;
  final UserModel customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('مدربو ${field.name}')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: ref
                .watch(coachServiceProvider)
                .watchCoaches(field.fieldId, activeOnly: true),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'تعذر تحميل المدربين حالياً. تحقق من اتصالك وحاول مجدداً.',
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
                return const SportsEmptyState(
                  title: 'لا تتوفر جلسات تدريب حالياً',
                  message: 'يمكنك حجز الملعب مباشرة أو العودة لاحقاً.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: coaches.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final coach = coaches[index];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                child: Text(
                                  coach.name.substring(0, 1),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
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
                            ],
                          ),
                          if (coach.bio.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(coach.bio),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.sports_soccer_outlined, size: 19),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${field.pricePerHour.toStringAsFixed(2)} USD ملعب'
                                  ' + ${coach.pricePerHour.toStringAsFixed(2)} USD تدريب / ساعة',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => BookingScreen(
                                  field: field,
                                  customer: customer,
                                  coach: coach,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.event_available_outlined),
                            label: const Text('احجز جلسة تدريب'),
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
