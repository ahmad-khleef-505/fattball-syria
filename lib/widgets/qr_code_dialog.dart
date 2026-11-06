import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fattball/models/field_model.dart';

class QrCodeDialog extends StatelessWidget {
  const QrCodeDialog({super.key, required this.field});

  final FieldModel field;

  @override
  Widget build(BuildContext context) {
    // الرابط الذي سيتم فتحه عند مسح الكود
    final String qrData = 'https://fattball.app/field/${field.fieldCode}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'رمز الاستجابة السريعة (QR)',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'اطبع هذا الرمز وضعه على مدخل الملعب. يمكن للاعبين مسحه للدخول مباشرة إلى صفحة الحجز.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'كود الملعب: ${field.fieldCode}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إغلاق'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}