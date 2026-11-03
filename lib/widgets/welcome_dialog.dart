import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WelcomeDialog extends StatelessWidget {
  const WelcomeDialog({super.key});

  Future<void> _contactSupport() async {
    const phone = '+963981359229';
    const message =
        'مرحباً فريق دعم تطبيق Fattball،\nأنا مستخدم جديد وأحتاج إلى بعض المساعدة/الاستفسار.';
    final uri = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // يمكن إضافة رسالة خطأ هنا إذا لزم الأمر
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
          horizontal: 24, vertical: 40), // يمنع النافذة من أخذ كامل العرض
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1B5E20), // أخضر عشبي داكن
              Color(0xFF121212), // أسود عميق
            ],
          ),
          border: Border.all(
              color: Colors.white.withOpacity(0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // أيقونة التطبيق
            const Icon(Icons.sports_soccer,
                size: 64, color: Color(0xFF00E676)),
            const SizedBox(height: 16),

            // رسالة الترحيب
            const Text(
              'أهلاً بك في Fattball!',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'يسعدنا انضمامك إلينا. نحن هنا لنمنحك أفضل تجربة لحجز ملاعب كرة القدم في سوريا.',
              style:
                  TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),
            Divider(color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),

            // أسماء الإدارة (تم إصلاح الخطأ الإملائي والمسافات هنا)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Column(
                  children: [
                    Text('المدير التقني',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 12)),
                    SizedBox(height: 4),
                    Text('أحمد الخليف',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ],
                ),
                Container(
                    height: 30,
                    width: 1,
                    color: Colors.white.withOpacity(0.3)),
                const Column(
                  children: [
                    Text('المدير الفني',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 12)),
                    SizedBox(height: 4),
                    Text('محمد نور',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),
            Divider(color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),

            // زر الدعم الفني
            const Text(
              'لأي استفسار أو مشكلة، تواصل مع الدعم الفني:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _contactSupport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366), // لون واتساب
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.chat_bubble_outline, size: 20),
              label: const Text(
                'الدعم الفني عبر واتساب\n+963 981 359 229',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ),

            const SizedBox(height: 20),

            // زر الإغلاق
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'ابدأ الآن',
                style: TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}