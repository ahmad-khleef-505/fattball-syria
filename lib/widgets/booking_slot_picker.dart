import 'package:fattball/models/booking_model.dart';
import 'package:fattball/models/field_model.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class BookingSlotPicker extends StatefulWidget {
  BookingSlotPicker({
    super.key,
    required this.field,
    required this.bookings,
    required this.onSlotSelected,
    this.slotDuration = const Duration(hours: 1),
  }) {
    if (slotDuration.inMicroseconds <= 0) {
      throw ArgumentError.value(slotDuration, 'slotDuration');
    }
  }

  final FieldModel field;
  final List<BookingModel> bookings;
  final ValueChanged<DateTimeRange> onSlotSelected;
  final Duration slotDuration;

  @override
  State<BookingSlotPicker> createState() => _BookingSlotPickerState();
}

class _BookingSlotPickerState extends State<BookingSlotPicker> {
  late final timezone.Location _damascus;
  late DateTime _selectedDay;
  DateTimeRange? _selectedSlot;

  @override
  void initState() {
    super.initState();
    timezone_data.initializeTimeZones();
    _damascus = timezone.getLocation('Asia/Damascus');
    final now = timezone.TZDateTime.now(_damascus);
    _selectedDay = _dateOnly(now);
  }

  timezone.TZDateTime _dateOnly(DateTime date) {
    return timezone.TZDateTime(_damascus, date.year, date.month, date.day);
  }

  Future<void> _selectDay() async {
    final now = timezone.TZDateTime.now(_damascus);
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(
        _selectedDay.year,
        _selectedDay.month,
        _selectedDay.day,
      ),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
      helpText: 'اختر يوم الحجز',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );
    if (selected == null || !mounted) return;

    setState(() {
      _selectedDay = _dateOnly(selected);
      _selectedSlot = null;
    });
  }

  List<DateTimeRange> _buildSlots() {
    final openParts = _parseTime(widget.field.openTime);
    final closeParts = _parseTime(widget.field.closeTime);
    var opening = timezone.TZDateTime(
      _damascus,
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      openParts.$1,
      openParts.$2,
    );
    var closing = timezone.TZDateTime(
      _damascus,
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      closeParts.$1,
      closeParts.$2,
    );
    if (!closing.isAfter(opening)) {
      closing = timezone.TZDateTime(
        _damascus,
        _selectedDay.year,
        _selectedDay.month,
        _selectedDay.day + 1,
        closeParts.$1,
        closeParts.$2,
      );
    }

    final slots = <DateTimeRange>[];
    var start = opening;
    while (true) {
      final end = start.add(widget.slotDuration);
      if (end.isAfter(closing)) break;
      slots.add(DateTimeRange(start: start, end: end));
      start = start.add(const Duration(minutes: 30));
    }
    return slots;
  }

  (int, int) _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      throw const FormatException('صيغة وقت عمل الملعب غير صالحة.');
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw const FormatException('صيغة وقت عمل الملعب غير صالحة.');
    }
    return (hour, minute);
  }

  bool _isBooked(DateTimeRange slot) {
    return widget.bookings.any((booking) {
      if (booking.status == BookingStatus.cancelled) return false;
      return booking.startAt.isBefore(slot.end) &&
          booking.endAt.isAfter(slot.start);
    });
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final List<DateTimeRange> slots;
    try {
      slots = _buildSlots();
    } on FormatException catch (error) {
      return Center(
        child: Text(
          error.message,
          textAlign: TextAlign.center,
        ),
      );
    }

    final now = timezone.TZDateTime.now(_damascus);
    final availableSlots = slots.where((slot) => !_isBooked(slot)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _selectDay,
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text('يوم الحجز: ${_formatDate(_selectedDay)}'),
        ),
        const SizedBox(height: 12),
        if (availableSlots.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'لا توجد فترات متاحة في هذا اليوم.',
              textAlign: TextAlign.center,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final slot in slots)
                _SlotButton(
                  start: _formatTime(slot.start),
                  end: _formatTime(slot.end),
                  isBooked: _isBooked(slot),
                  isSelected: _selectedSlot?.start == slot.start &&
                      _selectedSlot?.end == slot.end,
                  onPressed: !slot.start.isAfter(now) || _isBooked(slot)
                      ? null
                      : () {
                          setState(() => _selectedSlot = slot);
                          widget.onSlotSelected(slot);
                        },
                ),
            ],
          ),
      ],
    );
  }
}

class _SlotButton extends StatelessWidget {
  const _SlotButton({
    required this.start,
    required this.end,
    required this.isBooked,
    required this.isSelected,
    required this.onPressed,
  });

  final String start;
  final String end;
  final bool isBooked;
  final bool isSelected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = isBooked ? '$start - محجوز' : '$start - $end';
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor:
            isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
        foregroundColor: isBooked ? Theme.of(context).colorScheme.error : null,
      ),
      child: Text(label),
    );
  }
}
