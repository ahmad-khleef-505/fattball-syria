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

        final bookings = snapshot.data!.docs;
        int totalBookings = bookings.length;
        double expectedRevenue = 0.0;
        int confirmed = 0;

        for (var doc in bookings) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'];
          if (status == 'confirmed' || status == 'completed') {
            confirmed++;
            expectedRevenue += (data['totalPrice'] ?? 0).toDouble();
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              _buildStatCard(context, 'إجمالي الحجوزات', totalBookings.toString(), Icons.calendar_month, Colors.blue),
              const SizedBox(width: 12),
              _buildStatCard(context, 'الأرباح', '\$${expectedRevenue.toStringAsFixed(0)}', Icons.attach_money, Colors.green),
              const SizedBox(width: 12),
              _buildStatCard(context, 'المؤكدة', confirmed.toString(), Icons.check_circle, Colors.orange),
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