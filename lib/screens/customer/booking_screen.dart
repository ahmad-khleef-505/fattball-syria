import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/booking_model.dart';
import 'package:fattball/models/coach_model.dart';
import 'package:fattball/models/field_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/services/booking_service.dart';
import 'package:fattball/widgets/booking_slot_picker.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:fattball/widgets/responsive_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({
    super.key,
    required this.field,
    required this.customer,
    this.coach,
  });

  final FieldModel field;
  final UserModel customer;
  final CoachModel? coach;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  late final timezone.Location _damascus;
  DateTimeRange? _selectedSlot;
  DateTime _selectedDay = DateTime.now();
  final _childNameController = TextEditingController();
  final _childAgeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    timezone_data.initializeTimeZones();
    _damascus = timezone.getLocation('Asia/Damascus');
  }

  @override
  void dispose() {
    _childNameController.dispose();
    _childAgeController.dispose();
    super.dispose();
  }

  String _getCurrencySymbol(String currency) {
    switch (currency) {
      case 'USD': return '\$';
      case 'SYP': return 'ل.س';
      case 'TRY': return 'TL';
      default: return currency;
    }
  }

  void _onDayChanged(DateTime newDay) {
    setState(() {
      _selectedDay = newDay;
      _selectedSlot = null;
    });
  }

  Future<void> _submit() async {
    final slot = _selectedSlot;
    if (slot == null) {
      HapticFeedback.heavyImpact();
      _showMessage('اختر الفترة التي تريد حجزها أولاً.');
      return;
    }
    final childName = _childNameController.text.trim();
    final childAge = int.tryParse(_childAgeController.text.trim());
    if (widget.coach != null &&
        (childName.length < 2 || childAge == null || childAge < 3 || childAge > 17)) {
      _showMessage('أدخل الاسم الأول للطفل وعمره بين 3 و17 سنة.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await ref.read(bookingServiceProvider).createBooking(
            field: widget.field,
            customer: widget.customer,
            startAt: slot.start,
            endAt: slot.end,
            coach: widget.coach,
            trainingChildName: widget.coach == null ? null : childName,
            trainingChildAge: widget.coach == null ? null : childAge,
          );
      if (!mounted) return;
      if (result is BookingCreated) {
        HapticFeedback.heavyImpact();
        _showMessage('تم إرسال طلب الحجز بنجاح. بانتظار موافقة صاحب الملعب.');
        Navigator.of(context).pop();
      } else if (result is BookingConflict) {
        _showMessage(result.message);
      } else if (result is BookingRejected) {
        _showMessage(result.message);
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

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String _formatDate(DateTime date) {
    final local = timezone.TZDateTime.from(date, _damascus);
    return '${local.year}/${local.month}/${local.day}';
  }

  @override
  Widget build(BuildContext context) {
    final locksStream = FirebaseFirestore.instance
        .collection('booking_locks')
        .where('fieldId', isEqualTo: widget.field.fieldId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('اختيار موعد الحجز')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: locksStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('تعذر تحميل المواعيد: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookings = _extractBookings(snapshot.data?.docs ?? []);

          return ResponsiveContent(
            maxWidth: 900,
            padding: EdgeInsets.zero,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.field.name, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text('${widget.field.governorate} - ${widget.field.district}'),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.field.pricePerHour.toStringAsFixed(0)} ${_getCurrencySymbol(widget.field.currency)} / 90 دقيقة',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        // 🚀 عرض أوقات العمل الفعلية للتوضيح
                        Text(
                          'أوقات العمل: ${widget.field.openTime} إلى ${widget.field.closeTime}',
                          style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('اختر اليوم', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('اليوم'),
                                selected: _isSameDay(_selectedDay, DateTime.now()),
                                onSelected: (_) => _onDayChanged(DateTime.now()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('غداً'),
                                selected: _isSameDay(_selectedDay, DateTime.now().add(const Duration(days: 1))),
                                onSelected: (_) => _onDayChanged(DateTime.now().add(const Duration(days: 1))),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ActionChip(
                                avatar: const Icon(Icons.calendar_month, size: 18),
                                label: const Text('تاريخ آخر'),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDay,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                  );
                                  if (picked != null) _onDayChanged(picked);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'التاريخ المحدد: ${_formatDate(_selectedDay)}',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('اختر الوقت', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                BookingSlotPicker(
                  field: widget.field,
                  bookings: bookings,
                  selectedDay: _selectedDay,
                  onSlotSelected: (slot) => setState(() => _selectedSlot = slot),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _isSubmitting || _selectedSlot == null ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check_circle_outline),
          label: const Text('إرسال طلب الحجز'),
        ),
      ),
    );
  }

  List<BookingModel> _extractBookings(List<QueryDocumentSnapshot<Map<String, dynamic>>> documents) {
    final bookings = <BookingModel>[];
    for (final doc in documents) {
      final data = doc.data();
      final reservations = data['reservations'] as Map<String, dynamic>?;
      if (reservations == null) continue;
      for (final r in reservations.values) {
        if (r is! Map<String, dynamic>) continue;
        final start = r['startAt'] as Timestamp?;
        final end = r['endAt'] as Timestamp?;
        final status = r['status'] as String?;
        if (start != null && end != null && status != 'cancelled') {
          bookings.add(BookingModel(
            bookingId: r['bookingId'] ?? '',
            fieldId: widget.field.fieldId,
            ownerId: widget.field.ownerId,
            customerId: '',
            customerName: '',
            startAt: start.toDate(),
            endAt: end.toDate(),
            status: BookingStatus.values.firstWhere((e) => e.name == status, orElse: () => BookingStatus.pending),
            totalPrice: 0,
            createdAt: start.toDate(),
          ));
        }
      }
    }
    return bookings;
  }
}