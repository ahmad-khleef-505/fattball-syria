import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/field_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/screens/owner/owner_coaches_screen.dart';
import 'package:fattball/screens/owner/field_form.dart';
import 'package:fattball/screens/owner/owner_bookings.dart';
import 'package:fattball/screens/owner/promo_codes_screen.dart';
import 'package:fattball/screens/owner/subscription_screen.dart';
import 'package:fattball/screens/tournaments/tournament_screens.dart';
import 'package:fattball/screens/community/community_board_screen.dart';
import 'package:fattball/screens/profile/profile_screen.dart';
import 'package:fattball/widgets/responsive_scaffold.dart';
import 'package:fattball/widgets/sports_loading.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:fattball/widgets/owner_analytics_panel.dart';
import 'package:fattball/services/auth_service.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OwnerDashboard extends ConsumerWidget {
  const OwnerDashboard({super.key, required this.user});

  final UserModel user;

  Future<void> _openForm(
    BuildContext context,
    FieldModel? field,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FieldForm(user: user, field: field),
      ),
    );
  }

  String _firestoreErrorMessage(Object? error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'ليست لديك صلاحية عرض ملاعبك. تحقق من إعدادات Firebase.',
        'unavailable' => 'الخدمة غير متاحة حالياً. تحقق من اتصالك.',
        _ => 'تعذر تحميل ملاعبك. يرجى المحاولة مجدداً.',
      };
    }
    return 'تعذر تحميل ملاعبك. يرجى المحاولة مجدداً.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fieldsStream = FirebaseFirestore.instance
        .collection('fields')
        .where('ownerId', isEqualTo: user.uid)
        .snapshots();

    return ResponsiveScaffold(
      title: 'لوحة صاحب الملعب',
      destinations: const [
        ResponsiveDestination(
          label: 'ملاعبك',
          icon: Icons.stadium_outlined,
          selectedIcon: Icons.stadium,
        ),
        ResponsiveDestination(
          label: 'الحجوزات',
          icon: Icons.event_note_outlined,
        ),
        ResponsiveDestination(
          label: 'الاشتراك',
          icon: Icons.workspace_premium_outlined,
        ),
        ResponsiveDestination(
          label: 'حسابي',
          icon: Icons.person_outline,
        ),
      ],
      selectedIndex: 0,
      onDestinationSelected: (index) {
        if (index == 1) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OwnerBookingsScreen(owner: user),
            ),
          );
        } else if (index == 2) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OwnerSubscriptionScreen(owner: user),
            ),
          );
        } else if (index == 3) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProfileScreen(user: user),
            ),
          );
        }
      },
      actions: [
        IconButton(
          tooltip: 'مجتمع الملاعب',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CommunityBoardScreen(user: user),
            ),
          ),
          icon: const Icon(Icons.forum_outlined),
        ),
        IconButton(
          tooltip: 'إدارة البطولات',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OwnerTournamentsScreen(owner: user),
            ),
          ),
          icon: const Icon(Icons.emoji_events_outlined),
        ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, null),
        icon: const Icon(Icons.add),
        label: const Text('إضافة ملعب'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: fieldsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _firestoreErrorMessage(snapshot.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const FieldGridShimmer();
          }

          final documents = snapshot.data?.docs ?? [];
          final parsedFields = <FieldModel?>[];
          final validFields = <FieldModel>[];
          for (final document in documents) {
            try {
              final field = FieldModel.fromMap(
                document.id,
                document.data(),
              );
              parsedFields.add(field);
              validFields.add(field);
            } on FormatException {
              parsedFields.add(null);
            } on TypeError {
              parsedFields.add(null);
            }
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = AppBreakpoints.gridColumns(constraints.maxWidth);
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: OwnerAnalyticsPanel(
                      owner: user,
                      fields: validFields,
                      hasInvalidFieldData:
                          validFields.length != documents.length,
                    ),
                  ),
                  if (documents.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyFields(
                        onAdd: () => _openForm(context, null),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        12,
                        16,
                        96,
                      ),
                      sliver: SliverGrid(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 184,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final field = parsedFields[index];
                            if (field == null) {
                              return const Card(
                                child: ListTile(
                                  leading: Icon(Icons.error_outline),
                                  title: Text(
                                    'تعذر قراءة بيانات هذا الملعب.',
                                  ),
                                ),
                              );
                            }
                    final expiry = field.ownerSubscriptionExpiry;
                    final published = field.isActive &&
                        user.isActive &&
                        expiry != null &&
                        expiry.isAfter(DateTime.now());

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: field.images.isEmpty
                                ? ColoredBox(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: Icon(Icons.sports_soccer),
                                  )
                                : Image.network(
                                    field.images.first,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => ColoredBox(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                          ),
                        ),
                        title: Text(field.name),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${field.governorate} - ${field.district}'),
                              const SizedBox(height: 4),
                              Text(
                                '${field.pricePerHour.toStringAsFixed(2)} USD / ساعة',
                              ),
                              const SizedBox(height: 6),
                              Text(
                                published
                                    ? 'منشور'
                                    : 'غير منشور — يحتاج اشتراكاً فعالاً',
                                style: TextStyle(
                                  color: published
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.error,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => OwnerCoachesScreen(
                                    field: field,
                                    owner: user,
                                  ),
                                ),
                                ),
                                icon: const Icon(Icons.sports, size: 18),
                                label: const Text('إدارة المدربين'),
                                style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                alignment: AlignmentDirectional.centerStart,
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'إدارة أكواد الخصم',
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => OwnerPromoCodesScreen(
                                    owner: user,
                                    field: field,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.local_offer_outlined),
                            ),
                            IconButton(
                              tooltip: 'تعديل الملعب',
                              onPressed: () => _openForm(context, field),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                          },
                          childCount: documents.length,
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyFields extends StatelessWidget {
  const _EmptyFields({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_soccer_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'لم تضف أي ملعب بعد.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'أضف بيانات ملعبك وموقعه وصوره للبدء.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('إضافة ملعب'),
            ),
          ],
        ),
      ),
    );
  }
}
