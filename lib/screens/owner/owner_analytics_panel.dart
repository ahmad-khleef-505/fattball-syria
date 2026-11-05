import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OwnerAnalyticsPanel extends StatelessWidget {
  final String ownerId;
  const OwnerAnalyticsPanel({super.key, required this.ownerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('ownerId', isEqualTo: ownerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = DateTime(now.year, now.month, now.day + 1);

        int todayBookings = 0;
        double todayRevenue = 0.0;
        int todayConfirmed = 0;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final startAt = (data['startAt'] as Timestamp?)?.toDate();
          final status = data['status'];

          // حساب الإحصائيات لليوم الحالي فقط
          if (startAt != null && startAt.isAfter(startOfDay) && startAt.isBefore(endOfDay)) {
            todayBookings++;
            if (status == 'confirmed' || status == 'completed') {
              todayConfirmed++;
              todayRevenue += (data['totalPrice'] ?? 0).toDouble();
            }
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              _buildStatCard(context, 'حجوزات اليوم', todayBookings.toString(), Icons.calendar_month, Colors.blue),
              const SizedBox(width: 12),
              _buildStatCard(context, 'أرباح اليوم', '\$${todayRevenue.toStringAsFixed(0)}', Icons.attach_money, Colors.green),
              const SizedBox(width: 12),
              _buildStatCard(context, 'المؤكدة اليوم', todayConfirmed.toString(), Icons.check_circle, Colors.orange),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}