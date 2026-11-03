import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/core/constants.dart';
import 'package:fattball/models/booking_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/services/auth_service.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fattball/widgets/responsive_scaffold.dart';
import 'package:fattball/widgets/booking_ticket.dart';
import 'package:fattball/widgets/sports_loading.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key, required this.customer});

  final UserModel customer;

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  late final timezone.Location _damascus;

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

  String _errorMessage(Object? error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => 'ليست لديك صلاحية عرض حجوزاتك.',
        'unavailable' => 'الخدمة غير متاحة حالياً. تحقق من اتصالك.',
        'failed-precondition' =>
          'تعذر تحميل الحجوزات؛ قد يتطلب الأمر إنشاء فهرس Firestore.',
        _ => 'تعذر تحميل حجوزاتك. يرجى المحاولة مجدداً.',
      };
    }
    return 'تعذر تحميل حجوزاتك. يرجى المحاولة مجدداً.';
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authServiceProvider).signOut();
    } on AuthServiceException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          glassSnackBar(content: Text(error.message)),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final bookingsStream = FirebaseFirestore.instance
        .collection('bookings')
        .where('customerId', isEqualTo: widget.customer.uid)
        .snapshots();

    return ResponsiveScaffold(
      title: 'حجوزاتي',
      destinations: const [
        ResponsiveDestination(
          label: 'استكشف',
          icon: Icons.sports_soccer_outlined,
        ),
        ResponsiveDestination(
          label: 'حجوزاتي',
          icon: Icons.receipt_long_outlined,
        ),
      ],
      selectedIndex: 1,
      onDestinationSelected: (index) {
        if (index == 0) Navigator.of(context).maybePop();
      },
      actions: [
        IconButton(
          tooltip: 'تسجيل الخروج',
          // تم ربط الزر بدالة التأكيد
          onPressed: _confirmSignOut,
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
            return const SportsEmptyState(
              title: 'لم تحجز ملعباً بعد!',
              message: 'المباراة القادمة تبدأ بخطوة. اكتشف الملاعب واحجز وقتك.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _BookingCard(
              booking: bookings[index],
              dateTime: _dateTime,
              statusLabel: _statusLabel,
              statusColor: _statusColor,
            ),
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.dateTime,
    required this.statusLabel,
    required this.statusColor,
  });

  final BookingModel booking;
  final String Function(DateTime date) dateTime;
  final String Function(BookingStatus status) statusLabel;
  final Color Function(BuildContext context, BookingStatus status) statusColor;

  @override
  Widget build(BuildContext context) {
    final fieldFuture = FirebaseFirestore.instance
        .collection('fields')
        .doc(booking.fieldId)
        .get();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BookingTicket(
          title: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: fieldFuture,
            builder: (context, snapshot) {
              final fieldName = snapshot.data?.data()?['name'];
              if (fieldName is String) {
                return Text(
                  fieldName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                );
              }
              if (snapshot.hasError) return const Text('تعذر تحميل اسم الملعب.');
              return const Text('جاري تحميل اسم الملعب...');
            },
          ),
          status: statusLabel(booking.status),
          statusColor: statusColor(context, booking.status),
          startAt: dateTime(booking.startAt),
          endAt: dateTime(booking.endAt),
          totalPrice: booking.totalPrice.toStringAsFixed(2),
          currencyCode: AppConstants.currencyCode,
          discountInfo: booking.promoCode == null
              ? null
              : 'كود ${booking.promoCode} — خصم ${booking.discountPercent}%'
                  '${booking.subtotalPrice == null ? '' : ' (وفرت ${(booking.subtotalPrice! - booking.totalPrice).toStringAsFixed(2)} USD)'}',
          depositInfo: booking.depositRequired
              ? 'العربون ${booking.depositAmount.toStringAsFixed(2)} USD — '
                  '${switch (booking.depositStatus) {
                'pending_approval' => 'بانتظار موافقة صاحب الملعب',
                'approved' => 'تمت الموافقة',
                'rejected' => 'لم تتم الموافقة',
                _ => 'قيد المراجعة',
              }}'
              : null,
          trainingInfo: booking.coachId == null
              ? null
              : 'جلسة تدريب مع ${booking.coachName ?? 'المدرب'} '
                  'للطفل ${booking.trainingChildName ?? ''}'
                  '${booking.trainingChildAge == null ? '' : ' (${booking.trainingChildAge} سنة)'}',
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_month, size: 18),
            label: const Text('أضف إلى تقويمي'),
            onPressed: () {
              final Event event = Event(
                title: 'مباراة في ملعب ${booking.fieldId}',
                description: 'تم الحجز عبر تطبيق Fattball',
                location: 'سوريا',
                startDate: booking.startAt,
                endDate: booking.endAt,
              );
              Add2Calendar.addEvent2Cal(event);
            },
          ),
        ),
      ],
    );
  }
}