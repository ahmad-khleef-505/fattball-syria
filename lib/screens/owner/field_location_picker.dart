import 'package:fattball/services/location_service.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:fattball/widgets/sports_map_layers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class FieldLocationPicker extends StatefulWidget {
  const FieldLocationPicker({super.key, required this.initialLocation});

  final LatLng initialLocation;

  @override
  State<FieldLocationPicker> createState() => _FieldLocationPickerState();
}

class _FieldLocationPickerState extends State<FieldLocationPicker> {
  final _locationService = LocationService();
  late LatLng _selectedLocation = widget.initialLocation;
  bool _isLocating = false;

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final location = await _locationService.getCurrentLocation();
      if (mounted) setState(() => _selectedLocation = location);
    } on LocationServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(glassSnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحديد موقع الملعب'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(_selectedLocation),
            icon: const Icon(Icons.check),
            label: const Text('اعتماد الموقع'),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 13,
              onTap: (_, point) => setState(() => _selectedLocation = point),
            ),
            children: [
              const SportsMapTileLayer(),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 52,
                    height: 52,
                    child: Icon(
                      Icons.location_on,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SportsMapAttribution(),
            ],
          ).animate().fadeIn(duration: 320.ms).slideY(
                begin: 0.025,
                end: 0,
                duration: 320.ms,
                curve: Curves.easeOutCubic,
              ),
          PositionedDirectional(
            start: 16,
            bottom: 24,
            child: FloatingActionButton(
              heroTag: 'field-location-current',
              onPressed: _isLocating ? null : _useCurrentLocation,
              tooltip: 'استخدام موقعي الحالي',
              child: _isLocating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
          PositionedDirectional(
            end: 16,
            bottom: 28,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  'اضغط على الخريطة لتحديد الموقع',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
