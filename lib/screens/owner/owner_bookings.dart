import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/core/constants.dart';
import 'package:fattball/models/booking_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/services/booking_service.dart';
import 'package:fattball/services/auth_service.dart';
import 'package:fattball/screens/owner/subscription_screen.dart';
import 'package:fattball/widgets/responsive_scaffold.dart';
import 'package:fattball/widgets/sports_loading.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class OwnerBookingsScreen extends ConsumerStatefulWidget {
  const OwnerBookingsScreen({super.key, required this.owner});

  final UserModel owner;

  @override
  ConsumerState<OwnerBookingsScreen> createState() =>
      _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends ConsumerState<OwnerBookingsScreen> {
  late final timezone.Location _damascus;
  final Set<String> _updatingBookingIds = {};

  @override
  void initState() {
    super.initState();
    timezone_data.initializeTimeZones();
    _damascus = timezone.getLocation(AppConstants.timeZone);
  }

  String _dateTime(DateTime date) {
    final local = timezone.TZDateTime.from(date, _damascus);
    return '${local.year.toString().padLeft(4, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')}  '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _statusLabel(BookingStatus status) {
    return switch (status) {
      BookingStatus.pending => 'بانتظار التأكيد',
      BookingStatus.confirmed => 'مؤكد',
      BookingStatus.cancelled => 'ملغى',
      BookingStatus.completed => 'مكتمل',
    };
  }

  Color _statusColor(BuildContext context, BookingStatus status) {
    return switch (status) {
      BookingStatus.pending => Theme.of(context).colorScheme.tertiary,
      BookingStatus.confirmed => Theme.of(context).colorScheme.primary,
      BookingStatus.cancelled => Theme.of(context).colorScheme.error,
      BookingStatus.completed => Theme.of(context).colorScheme.secondary,
    };
  }

  Future<void> _updateStatus(
    BookingModel booking,
    BookingStatus status,
  ) async {
    setState(() => _updatingBookingIds.add(booking.bookingId));
    try {
      await ref.read(bookingServiceProvider).updateBookingStatus(
            bookingId: booking.bookingId,
            ownerId: widget.owner.uid,
            status: status,
          );
      if (mounted) {
        _showMessage(
          switch (status) {
            BookingStatus.confirmed => 'تم تأكيد الحجز.',
            BookingStatus.cancelled => 'تم إلغاء الحجز وإتاحة الموعد.',
            BookingStatus.completed => 'تم تسجيل الحجز كمكتمل.',
            BookingStatus.pending => 'الحجز بانتظار التأكيد.',
          },
        );
      }
    } on BookingServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _updatingBookingIds.remove(booking.bookingId));
      }
    }
  }

  Future<void> _confirmCancellation(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الحجز'),
        content: const Text(
          'سيتم إلغاء الحجز وإتاحة الموعد لعملاء آخرين. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('إلغاء الحجز'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _updateStatus(booking, BookingStatus.cancelled);
    }
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

  String _errorMessage(Object? error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => 'ليست لديك صلاحية عرض هذه الحجوزات.',
        'unavailable' => 'الخدمة غير متاحة حالياً. تحقق من اتصالك.',
        'failed-precondition' =>
          'تعذر تحميل الحجوزات؛ قد يتطلب الأمر إنشاء فهرس Firestore.',
        _ => 'تعذر تحميل الحجوزات. يرجى المحاولة مجدداً.',
      };
    }
    return 'تعذر تحميل الحجوزات. يرجى المحاولة مجدداً.';
  }

  @override
  Widget build(BuildContext context) {
    final bookingsStream = FirebaseFirestore.instance
        .collection('bookings')
        .where('ownerId', isEqualTo: widget.owner.uid)
        .snapshots();

    return ResponsiveScaffold(
      title: 'حجوزات ملاعبي',
      destinations: const [
        ResponsiveDestination(
          label: 'ملاعبك',
          icon: Icons.stadium_outlined,
        ),
        ResponsiveDestination(
          label: 'الحجوزات',
          icon: Icons.event_note_outlined,
          selectedIcon: Icons.event_available,
        ),
        ResponsiveDestination(
          label: 'الاشتراك',
          icon: Icons.workspace_premium_outlined,
        ),
      ],
      selectedIndex: 1,
      onDestinationSelected: (index) {
        if (index == 0) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else if (index == 2) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OwnerSubscriptionScreen(owner: widget.owner),
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: bookingsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage(snapshot.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const BookingListShimmer();
          }

          final bookings = <BookingModel>[];
          for (final document in snapshot.data?.docs ?? []) {
            try {
              bookings.add(BookingModel.fromMap(document.id, document.data()));
            } on FormatException {
              return const Center(
                child: Text('تعذر قراءة بيانات أحد الحجوزات.'),
              );
            } on TypeError {
              return const Center(
                child: Text('بيانات أحد الحجوزات غير مكتملة.'),
              );
            } on ArgumentError {
              return const Center(
                child: Text('توجد حالة غير معروفة لأحد الحجوزات.'),
              );
            }
          }
          bookings.sort((a, b) => b.startAt.compareTo(a.startAt));

          if (bookings.isEmpty) {
            return const Center(child: Text('لا توجد حجوزات لملاعبك بعد.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return _OwnerBookingCard(
                booking: booking,
                dateTime: _dateTime,
                statusLabel: _statusLabel,
                statusColor: _statusColor,
                isUpdating: _updatingBookingIds.contains(booking.bookingId),
                onConfirm: () =>
                    _updateStatus(booking, BookingStatus.confirmed),
                onCancel: () => _confirmCancellation(booking),
                onComplete: () =>
                    _updateStatus(booking, BookingStatus.completed),
              );
            },
          );
        },
      ),
    );
  }
}

class _OwnerBookingCard extends StatelessWidget {
  const _OwnerBookingCard({
    required this.booking,
    required this.dateTime,
    required this.statusLabel,
    required this.statusColor,
    required this.isUpdating,
    required this.onConfirm,
    required this.onCancel,
    required this.onComplete,
  });

  final BookingModel booking;
  final String Function(DateTime date) dateTime;
  final String Function(BookingStatus status) statusLabel;
  final Color Function(BuildContext context, BookingStatus status) statusColor;
  final bool isUpdating;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final fieldFuture = FirebaseFirestore.instance
        .collection('fields')
        .doc(booking.fieldId)
        .get();
    final canManage = booking.status == BookingStatus.pending ||
        booking.status == BookingStatus.confirmed;
    final canComplete = booking.status == BookingStatus.confirmed &&
        !booking.endAt.isAfter(DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: fieldFuture,
                    builder: (context, snapshot) {
                      final name = snapshot.data?.data()?['name'];
                      if (name is String) {
                        return Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium,
                        );
                      }
                      if (snapshot.hasError) {
                        return const Text('تعذر تحميل اسم الملعب.');
                      }
                      return const Text('جاري تحميل اسم الملعب...');
                    },
                  ),
                ),
                Chip(
                  label: Text(statusLabel(booking.status)),
                  labelStyle: TextStyle(
                    color: statusColor(context, booking.status),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('العميل: ${booking.customerName}'),
            if (booking.coachId != null) ...[
              const SizedBox(height: 4),
              Text(
                'جلسة تدريب: ${booking.coachName ?? 'المدرب'} '
                '— الطفل ${booking.trainingChildName ?? ''}'
                '${booking.trainingChildAge == null ? '' : '، العمر ${booking.trainingChildAge} سنة'}',
              ),
            ],
            const SizedBox(height: 4),
            Text('من: ${dateTime(booking.startAt)}'),
            Text('إلى: ${dateTime(booking.endAt)}'),
            const SizedBox(height: 4),
            Text('الإجمالي: ${booking.totalPrice.toStringAsFixed(2)} USD'),
            if (booking.promoCode != null) ...[
              const SizedBox(height: 4),
              Text(
                'كود الخصم: ${booking.promoCode} '
                '(${booking.discountPercent}%)'
                '${booking.subtotalPrice == null ? '' : ' — قبل الخصم ${booking.subtotalPrice!.toStringAsFixed(2)} USD'}',
              ),
            ],
            if (booking.depositRequired) ...[
              const SizedBox(height: 8),
              Text(
                'العربون: ${booking.depositAmount.toStringAsFixed(2)} USD'
                ' — ${_depositMethodLabel(booking.depositMethod)}',
              ),
              Text(
                switch (booking.depositStatus) {
                  'pending_approval' => 'العربون بانتظار مراجعتك',
                  'approved' => 'تمت الموافقة على العربون',
                  'rejected' => 'رُفض العربون',
                  _ => 'حالة العربون غير معروفة',
                },
              ),
              if (booking.depositReceiptUrl != null) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => Dialog(
                      child: InteractiveViewer(
                        child: Image.network(
                          booking.depositReceiptUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('تعذر عرض صورة إثبات التحويل.'),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      booking.depositReceiptUrl!,
                      height: 100,
                      width: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Text(
                        'تعذر تحميل إثبات التحويل.',
                      ),
                    ),
                  ),
                ),
              ],
            ],
            if (canManage) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (booking.status == BookingStatus.pending)
                    FilledButton.icon(
                      onPressed: isUpdating ? null : onConfirm,
                      icon: isUpdating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        booking.depositRequired
                            ? 'قبول العربون وتأكيد الحجز'
                            : 'تأكيد الحجز',
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: isUpdating ? null : onCancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('إلغاء الحجز'),
                  ),
                  if (canComplete)
                    OutlinedButton.icon(
                      onPressed: isUpdating ? null : onComplete,
                      icon: const Icon(Icons.task_alt_outlined),
                      label: const Text('تسجيل كمكتمل'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _depositMethodLabel(String? method) {
    return switch (method) {
      'cash' => 'نقداً',
      'sham_cash' => 'شام كاش',
      'syriatel_cash' => 'سيرياتيل كاش',
      _ => 'غير محدد',
    };
  }
}
