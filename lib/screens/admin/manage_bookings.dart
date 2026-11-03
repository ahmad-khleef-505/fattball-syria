import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/booking_model.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/screens/admin/manage_owners.dart';
import 'package:fattball/widgets/responsive_scaffold.dart';
import 'package:fattball/widgets/sports_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class ManageBookingsScreen extends ConsumerStatefulWidget {
  const ManageBookingsScreen({super.key});

  @override
  ConsumerState<ManageBookingsScreen> createState() =>
      _ManageBookingsScreenState();
}

class _ManageBookingsScreenState extends ConsumerState<ManageBookingsScreen> {
  late final timezone.Location _damascus;
  BookingStatus? _statusFilter;
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    timezone_data.initializeTimeZones();
    _damascus = timezone.getLocation('Asia/Damascus');
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

  String _errorMessage(Object? error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => 'لا تملك صلاحية عرض الحجوزات.',
        'unavailable' => 'الخدمة غير متاحة حالياً. تحقق من اتصالك.',
        _ => 'تعذر تحميل الحجوزات. يرجى المحاولة مجدداً.',
      };
    }
    return 'تعذر تحميل الحجوزات. يرجى المحاولة مجدداً.';
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: 'جميع الحجوزات',
      destinations: const [
        ResponsiveDestination(
          label: 'الرئيسية',
          icon: Icons.dashboard_outlined,
        ),
        ResponsiveDestination(
          label: 'أصحاب الملاعب',
          icon: Icons.storefront_outlined,
        ),
        ResponsiveDestination(
          label: 'الحجوزات',
          icon: Icons.event_note_outlined,
          selectedIcon: Icons.event_available,
        ),
      ],
      selectedIndex: 2,
      onDestinationSelected: (index) {
        if (index == 0) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else if (index == 1) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ManageOwnersScreen(),
            ),
          );
        }
      },
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'بحث بالعميل أو الملعب أو المعرّف',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _searchTerm = value.trim()),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _FilterChip(
                  label: 'الكل',
                  selected: _statusFilter == null,
                  onSelected: () => setState(() => _statusFilter = null),
                ),
                for (final status in BookingStatus.values)
                  _FilterChip(
                    label: _statusLabel(status),
                    selected: _statusFilter == status,
                    onSelected: () => setState(() => _statusFilter = status),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: ref.read(adminServiceProvider).watchAllBookings(),
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
                for (final document in snapshot.data ?? []) {
                  try {
                    bookings.add(
                      BookingModel.fromMap(document.id, document.data()),
                    );
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

                final query = _searchTerm.toLowerCase();
                final filtered = bookings.where((booking) {
                  final matchesStatus =
                      _statusFilter == null || booking.status == _statusFilter;
                  final matchesSearch = query.isEmpty ||
                      booking.customerName.toLowerCase().contains(query) ||
                      booking.bookingId.toLowerCase().contains(query) ||
                      booking.fieldId.toLowerCase().contains(query) ||
                      booking.ownerId.toLowerCase().contains(query) ||
                      booking.customerId.toLowerCase().contains(query);
                  return matchesStatus && matchesSearch;
                }).toList()
                  ..sort((a, b) => b.startAt.compareTo(a.startAt));

                if (filtered.isEmpty) {
                  return const Center(child: Text('لا توجد حجوزات مطابقة.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _AdminBookingCard(
                    booking: filtered[index],
                    dateTime: _dateTime,
                    statusLabel: _statusLabel,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _AdminBookingCard extends StatelessWidget {
  const _AdminBookingCard({
    required this.booking,
    required this.dateTime,
    required this.statusLabel,
  });

  final BookingModel booking;
  final String Function(DateTime date) dateTime;
  final String Function(BookingStatus status) statusLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('الحجز ${booking.bookingId}')),
                Chip(label: Text(statusLabel(booking.status))),
              ],
            ),
            const SizedBox(height: 8),
            Text('العميل: ${booking.customerName} (${booking.customerId})'),
            Text('الملعب: ${booking.fieldId}'),
            Text('المالك: ${booking.ownerId}'),
            Text('من: ${dateTime(booking.startAt)}'),
            Text('إلى: ${dateTime(booking.endAt)}'),
            Text('الإجمالي: ${booking.totalPrice.toStringAsFixed(2)} USD'),
          ],
        ),
      ),
    );
  }
}
