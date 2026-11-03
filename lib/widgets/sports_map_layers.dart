import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

class SportsMapTileLayer extends StatelessWidget {
  const SportsMapTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      // رابط OpenStreetMap المجاني الذي لا يحتاج إلى API Key
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.fattball.syria', // معرف تطبيقك
      // إعدادات لجعل الخريطة أنعم
      tileBuilder: (context, tileWidget, tile) {
        return ColorFiltered(
          // لمسة رياضية: إعطاء الخريطة لوناً أخضر خفيفاً (اختياري)
          colorFilter: ColorFilter.mode(
            Theme.of(context).colorScheme.primary.withOpacity(0.05),
            BlendMode.srcOver,
          ),
          child: tileWidget,
        );
      },
    );
  }
}

class SportsMapAttribution extends StatelessWidget {
  const SportsMapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return const RichAttributionWidget(
      attributions: [
        TextSourceAttribution(
          'OpenStreetMap contributors',
          // يمكنك إضافة رابط إذا أردت
        ),
      ],
    );
  }
}