import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
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
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
  
  int _selectedSection = 0; 
  List<BookingModel> _currentBookings = [];

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

  // 🚀 دالة تصدير ملف CSV
  Future<void> _exportToCsv() async {
    if (_currentBookings.isEmpty) {
      _showMessage('لا توجد حجوزات لتصديرها.');
      return;
    }

    try {
      List<List<dynamic>> rows = [];
      
      rows.add([
        "اسم العميل",
        "التاريخ",
        "وقت البداية",
        "وقت النهاية",
        "السعر الإجمالي",
        "الحالة"
      ]);

      for (var booking in _currentBookings) {
        final startLocal = timezone.TZDateTime.from(booking.startAt, _damascus);
        final endLocal = timezone.TZDateTime.from(booking.endAt, _damascus);
        
        rows.add([
          booking.customerName,
          '${startLocal.year}/${startLocal.month}/${startLocal.day}',
          '${startLocal.hour.toString().padLeft(2, '0')}:${startLocal.minute.toString().padLeft(2, '0')}',
          '${endLocal.hour.toString().padLeft(2, '0')}:${endLocal.minute.toString().padLeft(2, '0')}',
          booking.totalPrice.toStringAsFixed(2),
          _statusLabel(booking.status)
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/bookings_report.csv';
      final file = File(path);
      
      await file.writeAsString(csvData, encoding: utf8);

      if (mounted) {
        await Share.shareXFiles([XFile(path)], text: 'تقرير حجوزات الملعب');
      }
    } catch (e) {
      if (mounted) _showMessage('تعذر تصدير التقرير. حاول مجدداً.');
    }
  }

  // 🚀 دالة إضافة الحجز اليدوي
  Future<void> _addManualBooking() async {
    final fieldsSnapshot = await FirebaseFirestore.instance
        .collection('fields')
        .where('ownerId', isEqualTo: widget.owner.uid)
        .get();
    
    if (!mounted) return;
    if (fieldsSnapshot.docs.isEmpty) {
      _showMessage('أضف ملعباً أولاً.');
      return;
    }

    var selectedFieldId = fieldsSnapshot.docs.first.id;
    var selectedDate = DateTime.now().add(const Duration(days: 1));
    var startTime = const TimeOfDay(hour: 18, minute: 0);
    var endTime = const TimeOfDay(hour: 19, minute: 30);
    final customerNameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة حجز يدوي'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedFieldId,
                  decoration: const InputDecoration(labelText: 'الملعب'),
                  items: fieldsSnapshot.docs.map((doc) => DropdownMenuItem(
                    value: doc.id,
                    child: Text(doc.data()['name'] as String),
                  )).toList(),
                  onChanged: (val) => setDialogState(() => selectedFieldId = val!),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: customerNameController,
                  decoration: const InputDecoration(labelText: 'اسم العميل (الكابتن)'),
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
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text('${selectedDate.year}/${selectedDate.month}/${selectedDate.day}'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(context: context, initialTime: startTime);
                          if (picked != null) setDialogState(() => startTime = picked);
                        },
                        child: Text('من: ${startTime.format(context)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(context: context, initialTime: endTime);
                          if (picked != null) setDialogState(() => endTime = picked);
                        },
                        child: Text('إلى: ${endTime.format(context)}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (customerNameController.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('حفظ الحجز'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      try {
        final startAt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, startTime.hour, startTime.minute);
        final endAt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, endTime.hour, endTime.minute);

        await ref.read(bookingServiceProvider).createManualBooking(
              ownerId: widget.owner.uid,
              fieldId: selectedFieldId,
              customerName: customerNameController.text.trim(),
              startAt: startAt,
              endAt: endAt,
            );
        if (mounted) _showMessage('تمت إضافة الحجز اليدوي بنجاح.');
      } on BookingServiceException catch (error) {
        if (mounted) _showMessage(error.message);
      }
    }
    customerNameController.dispose();
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
                    value: selectedFieldId,
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

  Future<void> _removeMaintenance(String maintenanceId, String fieldId) async {
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

  Future<void> _rescheduleBooking(BookingModel booking) async {
    final bookingStart = timezone.TZDateTime.from(booking.startAt, _damascus);
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(bookingStart.year, bookingStart.month, bookingStart.day),
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

  Future<void> _updateStatus(BookingModel booking, BookingStatus status) async {
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
        content: const Text('سيتم إلغاء الحجز وإتاحة الموعد لعملاء آخرين. هل تريد المتابعة؟'),
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
        'failed-precondition' => 'تعذر تحميل الحجوزات؛ قد يتطلب الأمر إنشاء فهرس Firestore.',
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
        ResponsiveDestination(label: 'ملاعبك', icon: Icons.stadium_outlined),
        ResponsiveDestination(label: 'الحجوزات', icon: Icons.event_note_outlined, selectedIcon: Icons.event_available),
        ResponsiveDestination(label: 'الاشتراك', icon: Icons.workspace_premium_outlined),
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
          tooltip: 'تصدير التقرير (CSV)',
          onPressed: _exportToCsv,
          icon: const Icon(Icons.download_outlined),
        ),
        IconButton(
          tooltip: 'الملف الشخصي',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => ProfileScreen(user: widget.owner)),
          ),
          icon: const Icon(Icons.person_outline),
        ),
        IconButton(
          tooltip: 'تسجيل الخروج',
          onPressed: _confirmSignOut,
          icon: const Icon(Icons.logout),
        ),
      ],
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'manual-booking',
            onPressed: _addManualBooking,
            tooltip: 'إضافة حجز يدوي',
            child: const Icon(Icons.add_circle_outline),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'maintenance',
            onPressed: _openMaintenanceManager,
            icon: const Icon(Icons.build_outlined),
            label: const Text('أوقات الصيانة'),
          ),
        ],
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
                      child: Text(_errorMessage(snapshot.error), textAlign: TextAlign.center),
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
                    return const Center(child: Text('تعذر قراءة بيانات أحد الحجوزات.'));
                  } on TypeError {
                    return const Center(child: Text('بيانات أحد الحجوزات غير مكتملة.'));
                  } on ArgumentError {
                    return const Center(child: Text('توجد حالة غير معروفة لأحد الحجوزات.'));
                  }
                }
                bookings.sort((a, b) => a.startAt.compareTo(b.startAt));
                _currentBookings = bookings;

                final now = DateTime.now();
                final startOfToday = DateTime(now.year, now.month, now.day);
                final endOfTomorrow = DateTime(now.year, now.month, now.day + 2);

                final visibleBookings = bookings.where((booking) {
                  if (_selectedSection == 0) {
                    return booking.startAt.isAfter(startOfToday) && 
                           booking.startAt.isBefore(endOfTomorrow);
                  } else {
                    return booking.startAt.isAfter(endOfTomorrow) || 
                           booking.startAt.isAtSameMomentAs(endOfTomorrow);
                  }
                }).toList();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment<int>(
                            value: 0,
                            icon: Icon(Icons.today_outlined),
                            label: Text('اليوم والغد'),
                          ),
                          ButtonSegment<int>(
                            value: 1,
                            icon: Icon(Icons.event_outlined),
                            label: Text('مستقبلية'),
                          ),
                        ],
                        selected: {_selectedSection},
                        onSelectionChanged: (selection) {
                          setState(() => _selectedSection = selection.first);
                        },
                      ),
                    ),
                    Expanded(
                      child: visibleBookings.isEmpty
                          ? SportsEmptyState(
                              title: 'لا توجد حجوزات',
                              message: _selectedSection == 0
                                  ? 'لا توجد حجوزات مسجلة لهذا اليوم أو الغد.'
                                  : 'لا توجد حجوزات مستقبلية مسجلة.',
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
                                  isUpdating: _updatingBookingIds.contains(booking.bookingId),
                                  onConfirm: () => _updateStatus(booking, BookingStatus.confirmed),
                                  onCancel: () => _confirmCancellation(booking),
                                  onComplete: () => _updateStatus(booking, BookingStatus.completed),
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
    final fieldFuture = FirebaseFirestore.instance.collection('fields').doc(booking.fieldId).get();
    
    final canManage = booking.status == BookingStatus.pending || booking.status == BookingStatus.confirmed;
    final canReschedule = canManage && booking.startAt.isAfter(DateTime.now());
    final canComplete = booking.status == BookingStatus.confirmed && !booking.endAt.isAfter(DateTime.now());

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
                        return Text(name, style: Theme.of(context).textTheme.titleMedium);
                      }
                      return const Text('جاري تحميل اسم الملعب...');
                    },
                  ),
                ),
                Chip(
                  label: Text(statusLabel(booking.status)),
                  labelStyle: TextStyle(color: statusColor(context, booking.status)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('العميل: ${booking.customerName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('من: ${dateTime(booking.startAt)}'),
            Text('إلى: ${dateTime(booking.endAt)}'),
            const SizedBox(height: 8),
            Text('الإجمالي: ${booking.totalPrice.toStringAsFixed(0)} USD', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            
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
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check),
                      label: const Text('قبول الحجز'),
                    ),
                  if (canReschedule)
                    OutlinedButton.icon(
                      onPressed: isUpdating ? null : onReschedule,
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: const Text('تأجيل'),
                    ),
                  OutlinedButton.icon(
                    onPressed: isUpdating ? null : onCancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('رفض'),
                  ),
                  if (canComplete)
                    OutlinedButton.icon(
                      onPressed: isUpdating ? null : onComplete,
                      icon: const Icon(Icons.task_alt_outlined),
                      label: const Text('مكتمل'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}