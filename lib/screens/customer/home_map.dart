import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/core/constants.dart';
import 'package:fattball/models/field_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/screens/customer/field_details.dart';
import 'package:fattball/screens/customer/favorites_screen.dart';
import 'package:fattball/screens/customer/my_bookings.dart';
import 'package:fattball/screens/customer/notifications_screen.dart'; // 🚀 استيراد شاشة الإشعارات
import 'package:fattball/screens/profile/profile_screen.dart';
import 'package:fattball/screens/community/community_board_screen.dart';
import 'package:fattball/screens/tournaments/tournament_screens.dart';
import 'package:fattball/services/auth_service.dart';
import 'package:fattball/widgets/responsive_scaffold.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:fattball/widgets/weather_widgets.dart';
import 'package:fattball/widgets/welcome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeMap extends ConsumerStatefulWidget {
  const HomeMap({super.key, required this.user});

  final UserModel user;

  @override
  ConsumerState<HomeMap> createState() => _HomeMapState();
}

class _HomeMapState extends ConsumerState<HomeMap> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _governorates = [];
  List<String> _districts = [];
  String? _selectedGovernorate;
  String? _selectedDistrict;
  String? _locationsError;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _checkAndShowWelcomeDialog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAndShowWelcomeDialog() async {
    final prefs = await SharedPreferences.getInstance();
    bool hasSeenWelcome =
        prefs.getBool('hasSeenWelcome_${widget.user.uid}') ?? false;

    if (!hasSeenWelcome && mounted) {
      Future.delayed(const Duration(milliseconds: 800), () async {
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const WelcomeDialog(),
          );
          await prefs.setBool('hasSeenWelcome_${widget.user.uid}', true);
        }
      });
    }
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
        setState(() => _locationsError = 'تعذر تحميل بيانات المحافظات من التطبيق.');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(glassSnackBar(content: Text(message)));
  }

  Future<void> _searchByCode() async {
    final code = _searchController.text.trim();
    if (code.isEmpty) {
      _showMessage('يرجى إدخال كود الملعب أولاً.');
      return;
    }

    setState(() => _isSearching = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('fields')
          .where('fieldCode', isEqualTo: code)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) _showMessage('لم يتم العثور على ملعب بهذا الكود.');
      } else {
        final doc = snapshot.docs.first;
        final field = FieldModel.fromMap(doc.id, doc.data());
        
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => FieldDetails(field: field, customer: widget.user),
          ),
        );
        _searchController.clear();
      }
    } catch (e) {
      if (mounted) _showMessage('حدث خطأ أثناء البحث. حاول مجدداً.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _openField(FieldModel field) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FieldDetails(field: field, customer: widget.user),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج بالفعل؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('لا'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('نعم'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _signOut();
    }
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
          _showMessage('تعذر عرض $malformedFields ملعباً بسبب نقص بياناته.');
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
        ResponsiveDestination(
          label: 'حسابي',
          icon: Icons.person_outline,
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
        } else if (index == 4) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProfileScreen(user: widget.user),
            ),
          );
        }
      },
      actions: [
        // 🚀 زر الإشعارات
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where('userId', isEqualTo: widget.user.uid)
              .where('isRead', isEqualTo: false)
              .snapshots(),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data?.docs.length ?? 0;
            return IconButton(
              tooltip: 'الإشعارات',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NotificationsScreen(customer: widget.user),
                  ),
                );
              },
              icon: Badge(
                isLabelVisible: unreadCount > 0,
                label: Text('$unreadCount'),
                child: const Icon(Icons.notifications_outlined),
              ),
            );
          },
        ),
        // 🚀 زر المفضلة
        IconButton(
          tooltip: 'المفضلة',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FavoritesScreen(customer: widget.user),
              ),
            );
          },
          icon: const Icon(Icons.favorite, color: Colors.redAccent),
        ),
        // زر تسجيل الخروج
        IconButton(
          tooltip: 'تسجيل الخروج',
          onPressed: _confirmSignOut,
          icon: const Icon(Icons.logout),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.search,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              onSubmitted: (_) => _searchByCode(),
              decoration: InputDecoration(
                hintText: 'ابحث بكود الملعب (حتى 5 أرقام)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching 
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: _searchByCode,
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
          
          _buildGlassFilters(),
          WeatherSummaryCard(governorate: _selectedGovernorate),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: fieldsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _buildPremiumErrorState(snapshot.error);
                }

                final fields = _visibleFields(snapshot.data?.docs ?? []);

                if (fields.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sports_soccer, size: 80, color: Theme.of(context).colorScheme.outlineVariant),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد ملاعب متاحة حالياً',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text('جرب تغيير المحافظة أو المنطقة أو البحث بالكود'),
                      ],
                    ),
                  ).animate().fadeIn().scale();
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 80),
                  itemCount: fields.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final field = fields[index];
                    return _buildPremiumFieldCard(field).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildFilterButton(
                  label: _selectedGovernorate ?? 'كل المحافظات',
                  icon: Icons.map_outlined,
                  onTap: () => _showPremiumPicker(isGovernorate: true),
                ),
              ),
              Container(width: 1, height: 24, color: Theme.of(context).dividerColor),
              Expanded(
                child: _buildFilterButton(
                  label: _selectedDistrict ?? 'كل المناطق',
                  icon: Icons.location_city_outlined,
                  onTap: _selectedGovernorate == null
                      ? null
                      : () => _showPremiumPicker(isGovernorate: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final isActive = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).disabledColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? Theme.of(context).colorScheme.onSurface : Theme.of(context).disabledColor,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, size: 18, color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).disabledColor),
          ],
        ),
      ),
    );
  }

  void _showPremiumPicker({required bool isGovernorate}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        List<Map<String, dynamic>> itemsToShow = [];
        if (isGovernorate) {
          itemsToShow = _governorates;
        } else {
          itemsToShow = _districts.map((d) => {'name': d}).toList();
        }

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Text(
                isGovernorate ? 'اختر المحافظة' : 'اختر المنطقة',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    ListTile(
                      title: Text(
                          isGovernorate ? 'كل المحافظات' : 'كل المناطق',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      leading: const Icon(Icons.apps),
                      onTap: () {
                        setState(() {
                          if (isGovernorate) {
                            _selectedGovernorate = null;
                            _selectedDistrict = null;
                            _districts = [];
                          } else {
                            _selectedDistrict = null;
                          }
                        });
                        Navigator.pop(context);
                      },
                    ),
                    ...itemsToShow.map((item) {
                      final name = item['name'] as String;
                      return ListTile(
                        title: Text(name),
                        leading: Icon(isGovernorate
                            ? Icons.location_on_outlined
                            : Icons.pin_drop_outlined),
                        onTap: () {
                          setState(() {
                            if (isGovernorate) {
                              _selectedGovernorate = name;
                              final gov = _governorates.firstWhere(
                                  (element) => element['name'] == name);
                              _districts =
                                  List<String>.from(gov['districts'] as List);
                              _selectedDistrict = null;
                            } else {
                              _selectedDistrict = name;
                            }
                          });
                          Navigator.pop(context);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumFieldCard(FieldModel field) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => _openField(field),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (field.images.isNotEmpty)
              Image.network(
                field.images.first,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 160,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(child: Icon(Icons.broken_image, size: 50)),
                ),
              )
            else
              Container(
                height: 160,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Center(child: Icon(Icons.sports_soccer, size: 60, color: Theme.of(context).colorScheme.primary)),
              ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          field.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${field.pricePerHour.toStringAsFixed(0)} ${field.currency}',
                          style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 4),
                      Text('${field.governorate} - ${field.district}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openField(field),
                      icon: const Icon(Icons.event_available),
                      label: const Text('احجز الآن'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumErrorState(Object? error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded,
                  size: 48, color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 24),
            Text(
              'عذراً، حدث خطأ',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'تعذر تحميل البيانات. تحقق من اتصالك بالإنترنت.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().scale(duration: 400.ms, curve: Curves.easeOutBack);
  }
}