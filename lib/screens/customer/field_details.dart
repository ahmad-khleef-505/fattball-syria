import 'package:fattball/models/field_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/screens/customer/booking_screen.dart';
import 'package:fattball/screens/customer/field_coaches_screen.dart';
import 'package:fattball/widgets/responsive_scaffold.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:fattball/widgets/field_reviews_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class FieldDetails extends StatelessWidget {
  const FieldDetails({
    super.key,
    required this.field,
    required this.customer,
  });

  final FieldModel field;
  final UserModel customer;

  void _openBooking(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingScreen(field: field, customer: customer),
      ),
    );
  }

  Future<void> _contactOwner(BuildContext context) async {
    final rawPhone = field.ownerPhone?.trim() ?? '';
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        glassSnackBar(
          content: const Text('لم يضف صاحب الملعب رقم واتساب للتواصل.'),
        ),
      );
      return;
    }

    var phone = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('00')) {
      phone = phone.substring(2);
    }
    if (phone.startsWith('0')) {
      phone = '963${phone.substring(1)}';
    } else if (!phone.startsWith('963')) {
      phone = '963$phone';
    }
    if (phone.length < 10 || phone.length > 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        glassSnackBar(content: const Text('رقم واتساب المسجل غير صالح.')),
      );
      return;
    }

    final message = 'مرحباً، أود الاستفسار عن حجز ملعب ${field.name} '
        'في ${field.district}، هل يمكن تزويدي بالمواعيد المتاحة؟';
    final uri = Uri.https('wa.me', '/$phone', {'text': message});
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          glassSnackBar(content: const Text('تعذر فتح واتساب على هذا الجهاز.')),
        );
      }
    } on PlatformException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          glassSnackBar(content: const Text('تعذر فتح واتساب على هذا الجهاز.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(field.name)),
      body: ResponsiveContent(
        padding: EdgeInsets.zero,
        child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          if (field.images.isNotEmpty)
            SizedBox(
              height: 260,
              child: PageView.builder(
                itemCount: field.images.length,
                itemBuilder: (context, index) => Image.network(
                  field.images[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFFE7EEE9),
                    child: Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
            )
          else
            const SizedBox(
              height: 200,
              child: ColoredBox(
                color: Color(0xFFE7EEE9),
                child: Center(child: Icon(Icons.sports_soccer, size: 72)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: '${field.governorate} - ${field.district}',
                ),
                _DetailRow(icon: Icons.place_outlined, label: field.address),
                _DetailRow(
                  icon: Icons.access_time,
                  label: '${field.openTime} - ${field.closeTime}',
                ),
                _DetailRow(
                  icon: Icons.attach_money,
                  label: '${field.pricePerHour.toStringAsFixed(2)} USD / ساعة',
                ),
                const SizedBox(height: 20),
                Text(
                  'عن الملعب',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(field.description),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FieldCoachesScreen(
                        field: field,
                        customer: customer,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.sports),
                  label: const Text('احجز جلسة تدريب لطفلك'),
                ),
                const SizedBox(height: 24),
                FieldReviewsSection(
                  fieldId: field.fieldId,
                  customer: customer,
                ),
              ],
            ),
          ),
        ],
      ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _contactOwner(context),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('واتساب'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _openBooking(context),
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('احجز الآن'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
