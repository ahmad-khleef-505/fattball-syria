import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/core/constants.dart';
import 'package:fattball/models/booking_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/services/booking_service.dart';
import 'package:fattball/services/auth_service.dart';
import 'package:fattball/screens/owner/subscription_screen.dart';
import 'package:fattball/screens/owner/owner_analytics_panel.dart';
import 'package:fattball/screens/profile/profile_screen.dart';
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
  bool _showAllBookings = false;

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

  Future<void> _rescheduleBooking(BookingModel booking) async {
    final bookingStart = timezone.TZDateTime.from(booking.startAt, _damascus);
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(
        bookingStart.year,
        bookingStart.month,
        bookingStart.day,
      ),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'اختر تاريخ الموعد الجديد',
    );
    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: bookingStart.hour, minute: bookingStart.minute),
      helpText: 'اختر وقت البداية الجديد',
    );
    if (selectedTime == null || !mounted) return;

    final startAt = timezone.TZDateTime(
      _damascus,
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    if (!startAt.isAfter(timezone.TZDateTime.now(_damascus))) {
      _showMessage('اختر وقتاً مستقبلياً.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد تغيير الموعد'),
        content: Text(
          'سيُنقل الحجز إلى ${_dateTime(startAt)} مع الحفاظ على مدته الأصلية. '
          'هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تغيير الموعد'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _updatingBookingIds.add(booking.bookingId));
    try {
      final endAt = startAt.add(booking.endAt.difference(booking.startAt));
      await ref.read(bookingServiceProvider).rescheduleBooking(
            bookingId: booking.bookingId,
            ownerId: widget.owner.uid,
            startAt: startAt,
            endAt: endAt,
          );
      if (mounted) _showMessage('تم تغيير موعد الحجز بنجاح.');
    } on BookingServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _updatingBookingIds.remove(booking.bookingId));
      }
    }
  }

  Future<void> _openMaintenanceManager() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('أوقات الصيانة'),
        content: SizedBox(
          width: 520,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: ref
                .read(bookingServiceProvider)
                .watchFieldMaintenance(widget.owner.uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('تعذر تحميل أوقات الصيانة.');
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final records = [...?snapshot.data?.docs]
                ..sort((first, second) {
                  final firstStart = first.data()['startAt'];
                  final secondStart = second.data()['startAt'];
                  if (firstStart is! Timestamp || secondStart is! Timestamp) {
                    return 0;
                  }
                  return firstStart.compareTo(secondStart);
                });
              if (records.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: SportsEmptyState(
                    title: 'لا توجد أوقات صيانة',
                    message: 'يمكنك إضافة يوم كامل أو فترة زمنية محددة.',
                  ),
                );
              }
              return SizedBox(
                height: 340,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final document = records[index];
                    final data = document.data();
                    final start = data['startAt'];
                    final end = data['endAt'];
                    final timeRange = start is Timestamp && end is Timestamp
                        ? '${_dateTime(start.toDate())} – '
                            '${_dateTime(end.toDate())}'
                        : 'وقت غير صالح';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(data['reason'] as String? ?? 'صيانة'),
                      subtitle: Text(timeRange),
                      trailing: IconButton(
                        tooltip: 'إلغاء فترة الصيانة',
                        onPressed: () => _removeMaintenance(
                          document.id,
                          data['fieldId'] as String? ?? '',
                        ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
          FilledButton.icon(
            onPressed: _createMaintenance,
            icon: const Icon(Icons.add),
            label: const Text('إضافة فترة'),
          ),
        ],
      ),
    );
  }

  Future<void> _createMaintenance() async {
    final fieldsSnapshot = await FirebaseFirestore.instance
        .collection('fields')
        .where('ownerId', isEqualTo: widget.owner.uid)
        .get();
    final ownedFields = fieldsSnapshot.docs
        .where((document) => document.data()['name'] is String)
        .toList();
    if (!mounted) return;
    if (ownedFields.isEmpty) {
      _showMessage('أضف ملعباً أولاً قبل تحديد أوقات الصيانة.');
      return;
    }

    final reasonController = TextEditingController();
    var selectedDate = DateTime.now().add(const Duration(days: 1));
    var startTime = const TimeOfDay(hour: 8, minute: 0);
    var endTime = const TimeOfDay(hour: 20, minute: 0);
    var wholeDay = true;
    String? selectedFieldId =
        ownedFields.length == 1 ? ownedFields.single.id : null;
    try {
      final result = await showDialog<
          (String, DateTime, TimeOfDay, TimeOfDay, bool, String)>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('إضافة فترة صيانة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedFieldId,
                    decoration: const InputDecoration(labelText: 'الملعب'),
                    items: [
                      for (final field in ownedFields)
                        DropdownMenuItem<String>(
                          value: field.id,
                          child: Text(field.data()['name'] as String),
                        ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => selectedFieldId = value),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLength: 160,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'سبب الصيانة',
                      hintText: 'مثال: صيانة أرضية الملعب',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      '${selectedDate.year}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: wholeDay,
                    onChanged: (value) =>
                        setDialogState(() => wholeDay = value ?? true),
                    title: const Text('حظر اليوم كاملاً'),
                  ),
                  if (!wholeDay) ...[
                    OutlinedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: startTime,
                        );
                        if (picked != null) {
                          setDialogState(() => startTime = picked);
                        }
                      },
                      child: Text('من الساعة ${startTime.format(context)}'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: endTime,
                        );
                        if (picked != null) {
                          setDialogState(() => endTime = picked);
                        }
                      },
                      child: Text('حتى الساعة ${endTime.format(context)}'),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: selectedFieldId == null ||
                        reasonController.text.trim().isEmpty
                    ? null
                    : () => Navigator.of(dialogContext).pop((
                        selectedFieldId!,
                        selectedDate,
                        startTime,
                        endTime,
                        wholeDay,
                        reasonController.text.trim(),
                      )),
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      );
      if (result == null || !mounted) return;
      final (fieldId, date, start, end, isWholeDay, reason) = result;
      final startAt = timezone.TZDateTime(
        _damascus,
        date.year,
        date.month,
        date.day,
        isWholeDay ? 0 : start.hour,
        isWholeDay ? 0 : start.minute,
      );
      final endAt = isWholeDay
          ? timezone.TZDateTime(_damascus, date.year, date.month, date.day + 1)
          : timezone.TZDateTime(
              _damascus,
              date.year,
              date.month,
              date.day,
              end.hour,
              end.minute,
            );
      if (!isWholeDay && !endAt.isAfter(startAt)) {
        _showMessage('يجب أن يكون وقت النهاية بعد وقت البداية في اليوم نفسه.');
        return;
      }
      await ref.read(bookingServiceProvider).addFieldMaintenance(
            fieldId: fieldId,
            startAt: startAt,
            endAt: endAt,
            reason: reason,
          );
    } on BookingServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _removeMaintenance(
    String maintenanceId,
    String fieldId,
  ) async {
    if (fieldId.isEmpty) return;
    try {
      await ref.read(bookingServiceProvider).removeFieldMaintenance(
            fieldId: fieldId,
            maintenanceId: maintenanceId,
          );
      if (mounted) _showMessage('تم إلغاء فترة الصيانة.');
    } on BookingServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    }
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
          tooltip: 'الملف الشخصي',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProfileScreen(user: widget.owner),
            ),
          ),
          icon: const Icon(Icons.person_outline),
        ),
        IconButton(
          tooltip: 'إدارة أوقات الصيانة',
          onPressed: _openMaintenanceManager,
          icon: const Icon(Icons.build_outlined),
        ),
        IconButton(
          tooltip: 'تسجيل الخروج',
          onPressed: _signOut,
          icon: const Icon(Icons.logout),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openMaintenanceManager,
        icon: const Icon(Icons.build_outlined),
        label: const Text('أوقات الصيانة'),
      ),
      body: Column(
        children: [
          OwnerAnalyticsPanel(ownerId: widget.owner.uid),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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

                final visibleBookings = _showAllBookings
                    ? bookings
                    : bookings
                        .where(
                          (booking) =>
                              booking.startAt.isAfter(DateTime.now()) &&
                              (booking.status == BookingStatus.pending ||
                                  booking.status == BookingStatus.confirmed),
                        )
                        .toList();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(
                            value: false,
                            icon: Icon(Icons.upcoming_outlined),
                            label: Text('القادمة'),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            icon: Icon(Icons.list_alt_outlined),
                            label: Text('كل الحجوزات'),
                          ),
                        ],
                        selected: {_showAllBookings},
                        onSelectionChanged: (selection) {
                          setState(() => _showAllBookings = selection.first);
                        },
                      ),
                    ),
                    Expanded(
                      child: visibleBookings.isEmpty
                          ? SportsEmptyState(
                              title: bookings.isEmpty
                                  ? 'لا توجد حجوزات حتى الآن'
                                  : 'لا توجد حجوزات قادمة',
                              message: bookings.isEmpty
                                  ? 'ستظهر هنا الحجوزات الجديدة لملاعبك.'
                                  : 'يمكنك عرض كل الحجوزات لمراجعة السجل السابق.',
                              actionLabel: bookings.isEmpty ? null : 'عرض كل الحجوزات',
                              onAction: bookings.isEmpty
                                  ? null
                                  : () => setState(() => _showAllBookings = true),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: visibleBookings.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final booking = visibleBookings[index];
                                return _OwnerBookingCard(
                                  booking: booking,
                                  dateTime: _dateTime,
                                  statusLabel: _statusLabel,
                                  statusColor: _statusColor,
                                  isUpdating: _updatingBookingIds
                                      .contains(booking.bookingId),
                                  onConfirm: () =>
                                      _updateStatus(booking, BookingStatus.confirmed),
                                  onCancel: () =>
                                      _confirmCancellation(booking),
                                  onComplete: () =>
                                      _updateStatus(booking, BookingStatus.completed),
                                  onReschedule: () => _rescheduleBooking(booking),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
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
    required this.onReschedule,
  });

  final BookingModel booking;
  final String Function(DateTime date) dateTime;
  final String Function(BookingStatus status) statusLabel;
  final Color Function(BuildContext context, BookingStatus status) statusColor;
  final bool isUpdating;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final VoidCallback onComplete;
  final VoidCallback onReschedule;

  @override
  Widget build(BuildContext context) {
    final fieldFuture = FirebaseFirestore.instance
        .collection('fields')
        .doc(booking.fieldId)
        .get();
    final canManage = booking.status == BookingStatus.pending ||
        booking.status == BookingStatus.confirmed;
    final canReschedule = canManage && booking.startAt.isAfter(DateTime.now());
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
                  if (canReschedule)
                    OutlinedButton.icon(
                      onPressed: isUpdating ? null : onReschedule,
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: const Text('إعادة الجدولة'),
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