import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

class SportsMapTileLayer extends StatelessWidget {
  const SportsMapTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TileLayer(
      urlTemplate: isDark
          ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      subdomains: isDark ? const ['a', 'b', 'c', 'd'] : const [],
      userAgentPackageName: 'com.fattball.app',
    );
  }
}

class SportsMapAttribution extends StatelessWidget {
  const SportsMapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RichAttributionWidget(
      attributions: [
        TextSourceAttribution(
          isDark
              ? '© OpenStreetMap contributors © CARTO'
              : '© OpenStreetMap contributors',
        ),
      ],
    );
  }
}
