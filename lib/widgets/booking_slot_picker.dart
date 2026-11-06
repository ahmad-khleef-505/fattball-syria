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
    required this.selectedDay,
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

    // قراءة وقت الفتح والإغلاق بدقة (ساعة ودقيقة)
    final openParts = widget.field.openTime.split(':');
    final openHour = int.tryParse(openParts[0]) ?? 8;
    final openMinute = openParts.length > 1 ? int.tryParse(openParts[1]) ?? 0 : 0;

    final closeParts = widget.field.closeTime.split(':');
    final closeHour = int.tryParse(closeParts[0]) ?? 23;
    final closeMinute = closeParts.length > 1 ? int.tryParse(closeParts[1]) ?? 0 : 0;

    final openTime = timezone.TZDateTime(
      _damascus,
      day.year,
      day.month,
      day.day,
      openHour,
      openMinute,
    );
    
    final closeTime = timezone.TZDateTime(
      _damascus,
      day.year,
      day.month,
      day.day,
      closeHour,
      closeMinute,
    );

    // توليد الفترات المتتالية كل 90 دقيقة
    final slots = <_TimeSlot>[];
    var currentStart = openTime;

    while (true) {
      final currentEnd = currentStart.add(const Duration(minutes: 90));
      
      // إذا كانت الفترة ستتجاوز وقت الإغلاق، نتوقف
      if (currentEnd.isAfter(closeTime)) {
        break;
      }

      final isPast = currentStart.isBefore(timezone.TZDateTime.now(_damascus));
      final isBooked = widget.bookings.any((b) {
        return b.startAt.isBefore(currentEnd) && b.endAt.isAfter(currentStart);
      });

      slots.add(_TimeSlot(
        start: currentStart,
        end: currentEnd,
        isAvailable: !isPast && !isBooked,
      ));

      // الفترة التالية تبدأ من نهاية الفترة الحالية
      currentStart = currentEnd;
    }

    if (slots.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'لا توجد أوقات متاحة في هذا اليوم (تأكد من أوقات عمل الملعب).',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: slots.map((slot) {
        final isSelected = _selected?.start == slot.start;
        
        return ChoiceChip(
          label: Text(
            '${slot.start.hour.toString().padLeft(2, '0')}:${slot.start.minute.toString().padLeft(2, '0')} - '
            '${slot.end.hour.toString().padLeft(2, '0')}:${slot.end.minute.toString().padLeft(2, '0')}'
            '${!slot.isAvailable ? "\n(محجوز)" : ""}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: !slot.isAvailable 
                  ? Colors.grey 
                  : (isSelected ? Colors.white : Colors.black87),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          selected: isSelected,
          selectedColor: Theme.of(context).colorScheme.primary,
          onSelected: !slot.isAvailable 
              ? null 
              : (selected) {
                  setState(() {
                    _selected = selected ? DateTimeRange(start: slot.start, end: slot.end) : null;
                    widget.onSlotSelected(_selected);
                  });
                },
        );
      }).toList(),
    );
  }
}

class _TimeSlot {
  final DateTime start;
  final DateTime end;
  final bool isAvailable;

  _TimeSlot({required this.start, required this.end, required this.isAvailable});
}