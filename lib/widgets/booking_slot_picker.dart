import 'package:fattball/models/booking_model.dart';
import 'package:fattball/models/field_model.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class BookingSlotPicker extends StatefulWidget {
  const BookingSlotPicker({
    super.key,
    required this.field,
    required this.bookings,
    required this.selectedDay, // <--- هذا هو المتغير الذي كان ناقصاً
    required this.onSlotSelected,
  });

  final FieldModel field;
  final List<BookingModel> bookings;
  final DateTime selectedDay;
  final ValueChanged<DateTimeRange?> onSlotSelected;

  @override
  State<BookingSlotPicker> createState() => _BookingSlotPickerState();
}

class _BookingSlotPickerState extends State<BookingSlotPicker> {
  late final timezone.Location _damascus;
  DateTimeRange? _selected;

  @override
  void initState() {
    super.initState();
    timezone_data.initializeTimeZones();
    _damascus = timezone.getLocation('Asia/Damascus');
  }

  @override
  Widget build(BuildContext context) {
    final day = timezone.TZDateTime(
      _damascus,
      widget.selectedDay.year,
      widget.selectedDay.month,
      widget.selectedDay.day,
    );

    final openHour = int.tryParse(widget.field.openTime.split(':').first) ?? 8;
    final closeHour = int.tryParse(widget.field.closeTime.split(':').first) ?? 23;

    final slots = <DateTimeRange>[];
    for (var hour = openHour; hour < closeHour; hour++) {
      for (var minute = 0; minute < 60; minute += 30) {
        final start = timezone.TZDateTime(
          _damascus,
          day.year,
          day.month,
          day.day,
          hour,
          minute,
        );
        final end = start.add(const Duration(minutes: 90));
        
        if (end.hour > closeHour || (end.hour == closeHour && end.minute > 0)) {
          continue;
        }
        
        if (start.isBefore(timezone.TZDateTime.now(_damascus))) {
          continue;
        }

        final isBooked = widget.bookings.any((b) {
          return b.startAt.isBefore(end) && b.endAt.isAfter(start);
        });

        if (!isBooked) {
          slots.add(DateTimeRange(start: start, end: end));
        }
      }
    }

    if (slots.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('لا توجد أوقات متاحة في هذا اليوم.'),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((slot) {
        final isSelected = _selected?.start == slot.start;
        return ChoiceChip(
          label: Text(
            '${slot.start.hour.toString().padLeft(2, '0')}:${slot.start.minute.toString().padLeft(2, '0')}',
          ),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _selected = selected ? slot : null;
              widget.onSlotSelected(_selected);
            });
          },
        );
      }).toList(),
    );
  }
}