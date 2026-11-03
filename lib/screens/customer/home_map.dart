import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/core/constants.dart';
import 'package:fattball/core/theme.dart';
import 'package:fattball/models/field_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/screens/customer/field_details.dart';
import 'package:fattball/screens/customer/my_bookings.dart';
import 'package:fattball/screens/customer/assistant_chat_screen.dart';
import 'package:fattball/screens/community/community_board_screen.dart';
import 'package:fattball/screens/tournaments/tournament_screens.dart';
import 'package:fattball/services/auth_service.dart';
import 'package:fattball/services/location_service.dart';
import 'package:fattball/widgets/responsive_scaffold.dart';
import 'package:fattball/widgets/field_card.dart';
import 'package:fattball/widgets/sports_loading.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:fattball/widgets/sports_map_layers.dart';
import 'package:fattball/widgets/weather_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

class HomeMap extends ConsumerStatefulWidget {
  const HomeMap({super.key, required this.user});

  final UserModel user;

  @override
  ConsumerState<HomeMap> createState() => _HomeMapState();
}

class _HomeMapState extends ConsumerState<HomeMap>
    with SingleTickerProviderStateMixin {
  final _mapController = MapController();
  final LayerHitNotifier<String> _circleHitNotifier = ValueNotifier(null);
  final _locationService = LocationService();
  late final AnimationController _pulseController;

  List<Map<String, dynamic>> _governorates = [];
  List<String> _districts = [];
  String? _selectedGovernorate;
  String? _selectedDistrict;
  String? _selectedFieldId;
  String? _locationsError;
  double _zoom = 6;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _loadLocations();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _circleHitNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      final content =
          await rootBundle.loadString(AppConstants.locationsAssetPath);
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic> ||
          decoded['governorates'] is! List<dynamic>) {
        throw const FormatException('تنسيق بيانات المحافظات غير صالح.');
      }

      final governorates =
          (decoded['governorates'] as List<dynamic>).map((item) {
        if (item is! Map<String, dynamic> ||
            item['name'] is! String ||
            item['districts'] is! List<dynamic>) {
          throw const FormatException('تعذر قراءة بيانات المحافظة.');
        }
        return {
          'name': item['name'] as String,
          'districts': List<String>.from(item['districts'] as List),
        };
      }).toList();

      if (!mounted) return;
      setState(() => _governorates = governorates);
    } on FormatException catch (error) {
      if (mounted) setState(() => _locationsError = error.message);
    } on FlutterError {
      if (mounted) {
        setState(
          () => _locationsError = 'تعذر تحميل بيانات المحافظات من التطبيق.',
        );
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final location = await _locationService.getCurrentLocation();
      _mapController.move(location, math.max(_zoom, 13));
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

  void _openField(FieldModel field) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FieldDetails(field: field, customer: widget.user),
      ),
    );
  }

  void _openAssistant() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AssistantChatScreen(),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authServiceProvider).signOut();
    } on AuthServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  List<FieldModel> _visibleFields(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    final fields = <FieldModel>[];
    var malformedFields = 0;
    for (final document in documents) {
      try {
        final field = FieldModel.fromMap(document.id, document.data());
        final subscriptionExpiry = field.ownerSubscriptionExpiry;
        if (!field.isActive ||
            subscriptionExpiry == null ||
            !subscriptionExpiry.isAfter(DateTime.now())) {
          continue;
        }
        if (_selectedGovernorate != null &&
            field.governorate != _selectedGovernorate) {
          continue;
        }
        if (_selectedDistrict != null && field.district != _selectedDistrict) {
          continue;
        }
        fields.add(field);
      } on FormatException {
        malformedFields++;
      } on TypeError {
        malformedFields++;
      }
    }

    if (malformedFields > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showMessage(
            'تعذر عرض $malformedFields ملعباً بسبب نقص بياناته.',
          );
        }
      });
    }
    return fields;
  }

  @override
  Widget build(BuildContext context) {
    final fieldsStream = FirebaseFirestore.instance
        .collection('fields')
        .where('isActive', isEqualTo: true)
        .where(
          'ownerSubscriptionExpiry',
          isGreaterThan: Timestamp.fromDate(DateTime.now()),
        )
        .snapshots();

    return ResponsiveScaffold(
      title: AppConstants.appName,
      destinations: const [
        ResponsiveDestination(
          label: 'استكشف',
          icon: Icons.sports_soccer_outlined,
          selectedIcon: Icons.sports_soccer,
        ),
        ResponsiveDestination(
          label: 'حجوزاتي',
          icon: Icons.receipt_long_outlined,
        ),
        ResponsiveDestination(
          label: 'البطولات',
          icon: Icons.emoji_events_outlined,
        ),
        ResponsiveDestination(
          label: 'المجتمع',
          icon: Icons.forum_outlined,
        ),
      ],
      selectedIndex: 0,
      constrainBody: false,
      onDestinationSelected: (index) {
        if (index == 1) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MyBookingsScreen(customer: widget.user),
            ),
          );
        } else if (index == 2) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TournamentListScreen(customer: widget.user),
            ),
          );
        } else if (index == 3) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CommunityBoardScreen(user: widget.user),
            ),
          );
        }
      },
      actions: [
        IconButton(
          tooltip: 'تسجيل الخروج',
          onPressed: _signOut,
          icon: const Icon(Icons.logout),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'customer-ai-assistant',
        onPressed: _openAssistant,
        icon: const Icon(Icons.smart_toy_outlined),
        label: const Text('اسأل المساعد'),
      ),
      body: Column(
        children: [
          _buildFilters(),
          WeatherSummaryCard(governorate: _selectedGovernorate),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: fieldsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _firestoreError(snapshot.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: SportsShimmer(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.sports_soccer,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                }

                final fields = _visibleFields(snapshot.data?.docs ?? []);
                final selectedField = _fieldForId(fields, _selectedFieldId);
                final circles = fields
                    .map(
                      (field) => CircleMarker<String>(
                        point: LatLng(
                          field.geoPoint.latitude,
                          field.geoPoint.longitude,
                        ),
                        radius:
                            (8 + (_zoom - 5) * 1.35).clamp(7, 23).toDouble(),
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withAlpha(220),
                        borderColor: Colors.white,
                        borderStrokeWidth: 2,
                        hitValue: field.fieldId,
                      ),
                    )
                    .toList();

                return Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: const LatLng(34.8021, 38.9968),
                        initialZoom: 6,
                        minZoom: 4,
                        maxZoom: 18,
                        onPositionChanged: (camera, _) {
                          if ((camera.zoom - _zoom).abs() > 0.1) {
                            setState(() => _zoom = camera.zoom);
                          }
                        },
                        onTap: (_, __) =>
                            setState(() => _selectedFieldId = null),
                      ),
                      children: [
                        const SportsMapTileLayer(),
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () {
                            final hit = _circleHitNotifier.value?.hitValues;
                            if (hit != null && hit.isNotEmpty) {
                              setState(() => _selectedFieldId = hit.first);
                            }
                          },
                          child: CircleLayer<String>(
                            circles: circles,
                            hitNotifier: _circleHitNotifier,
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final pulse = _pulseController.value;
                            final markerSize =
                                (30 + (_zoom - 5) * 1.4).clamp(28, 48);
                            final haloCircles = fields
                                .map(
                                  (field) => CircleMarker<String>(
                                    point: LatLng(
                                      field.geoPoint.latitude,
                                      field.geoPoint.longitude,
                                    ),
                                    radius: (12 + (_zoom - 5) * 1.35)
                                        .clamp(11, 27)
                                        .toDouble(),
                                    color: AppTheme.neonGreen.withValues(
                                      alpha: 0.08 + pulse * 0.12,
                                    ),
                                    borderColor: AppTheme.neonGreen.withValues(
                                      alpha: 0.35 + pulse * 0.35,
                                    ),
                                    borderStrokeWidth: 2 + pulse * 2,
                                  ),
                                )
                                .toList();
                            return Stack(
                              children: [
                                CircleLayer<String>(circles: haloCircles),
                                MarkerLayer(
                                  markers: [
                                    for (final field in fields)
                                      Marker(
                                        point: LatLng(
                                          field.geoPoint.latitude,
                                          field.geoPoint.longitude,
                                        ),
                                        width: markerSize + pulse * 3,
                                        height: markerSize + pulse * 3,
                                        child: IgnorePointer(
                                          child: Icon(
                                            Icons.sports_soccer,
                                            size: markerSize + pulse * 3,
                                            color: AppTheme.neonGreen,
                                            shadows: [
                                              Shadow(
                                                color: AppTheme.neonGreen
                                                    .withValues(alpha: 0.8),
                                                blurRadius: 10 + pulse * 8,
                                              ),
                                              const Shadow(
                                                color: Colors.black87,
                                                blurRadius: 3,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        const SportsMapAttribution(),
                      ],
                    ),
                    PositionedDirectional(
                      top: 16,
                      start: 16,
                      child: FloatingActionButton.small(
                        heroTag: 'customer-current-location',
                        onPressed: _isLocating ? null : _useCurrentLocation,
                        tooltip: 'موقعي',
                        child: _isLocating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location),
                      ),
                    ),
                    if (fields.isEmpty)
                      PositionedDirectional(
                        top: 16,
                        end: 16,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              snapshot.data?.docs.isEmpty ?? true
                                  ? 'لا توجد ملاعب منشورة حالياً.'
                                  : 'لا توجد ملاعب في هذا النطاق.',
                            ),
                          ),
                        ),
                      ),
                    if (selectedField != null)
                      PositionedDirectional(
                        start: 16,
                        end: 16,
                        bottom: 20,
                        child: _FieldPopup(
                          field: selectedField,
                          onClose: () =>
                              setState(() => _selectedFieldId = null),
                          onBook: () => _openField(selectedField),
                        ),
                      ),
                    if (_locationsError != null)
                      PositionedDirectional(
                        start: 16,
                        end: 16,
                        top: 64,
                        child: Card(
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(_locationsError!),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final filters = [
          Expanded(child: _governorateFilter()),
          const SizedBox(width: 8, height: 8),
          Expanded(child: _districtFilter()),
        ];
        return ResponsiveContent(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: constraints.maxWidth < 480
              ? Column(
                  children: [
                    _governorateFilter(),
                    const SizedBox(height: 8),
                    _districtFilter(),
                  ],
                )
              : Row(children: filters),
        );
      },
    );
  }

  Widget _governorateFilter() {
    return DropdownButtonFormField<String?>(
      value: _selectedGovernorate,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'المحافظة',
        isDense: true,
        prefixIcon: Icon(Icons.map_outlined),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('كل المحافظات'),
        ),
        ..._governorates.map(
          (item) => DropdownMenuItem<String?>(
            value: item['name'] as String,
            child: Text(item['name'] as String),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedGovernorate = value;
          _selectedDistrict = null;
          _districts = value == null
              ? []
              : List<String>.from(
                  _governorates.firstWhere(
                    (item) => item['name'] == value,
                  )['districts'] as List,
                );
          _selectedFieldId = null;
        });
      },
    );
  }

  Widget _districtFilter() {
    return DropdownButtonFormField<String?>(
      value: _selectedDistrict,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'الحي / المنطقة',
        isDense: true,
        prefixIcon: Icon(Icons.location_city_outlined),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('كل المناطق'),
        ),
        ..._districts.map(
          (district) => DropdownMenuItem<String?>(
            value: district,
            child: Text(district),
          ),
        ),
      ],
      onChanged: _selectedGovernorate == null
          ? null
          : (value) => setState(() {
                _selectedDistrict = value;
                _selectedFieldId = null;
              }),
    );
  }

  FieldModel? _fieldForId(List<FieldModel> fields, String? id) {
    if (id == null) return null;
    for (final field in fields) {
      if (field.fieldId == id) return field;
    }
    return null;
  }

  String _firestoreError(Object? error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => 'تعذر عرض الملاعب بسبب إعدادات الصلاحيات.',
        'unavailable' => 'الخدمة غير متاحة حالياً. تحقق من اتصالك.',
        'failed-precondition' =>
          'تعذر تحميل الملاعب؛ قد يتطلب الأمر إنشاء فهرس Firestore.',
        _ => 'تعذر تحميل الملاعب. يرجى المحاولة مجدداً.',
      };
    }
    return 'تعذر تحميل الملاعب. يرجى المحاولة مجدداً.';
  }
}

class _FieldPopup extends StatelessWidget {
  const _FieldPopup({
    required this.field,
    required this.onClose,
    required this.onBook,
  });

  final FieldModel field;
  final VoidCallback onClose;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return FieldCard(
      field: field,
      onBook: onBook,
      onClose: onClose,
    ).animate().fadeIn(duration: 240.ms).slideY(
          begin: 0.08,
          end: 0,
          duration: 240.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
