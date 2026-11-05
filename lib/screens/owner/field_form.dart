import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/core/constants.dart';
import 'package:fattball/models/field_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/services/firestore_service.dart';
import 'package:fattball/widgets/responsive_scaffold.dart';
import 'package:fattball/widgets/sports_button.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class FieldForm extends ConsumerStatefulWidget {
  const FieldForm({super.key, required this.user, this.field});

  final UserModel user;
  final FieldModel? field;

  @override
  ConsumerState<FieldForm> createState() => _FieldFormState();
}

class _FieldFormState extends ConsumerState<FieldForm> {
  static const _maximumImages = 4;
  static const double _defaultLat = 33.5138;
  static const double _defaultLng = 36.2763;

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  
  final _nameController = TextEditingController();
  final _fieldCodeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _priceController = TextEditingController();
  final _ownerPhoneController = TextEditingController();

  List<Map<String, dynamic>> _governorates = [];
  List<String> _districts = [];
  final List<_PickedPhoto> _newPhotos = [];
  List<String> _existingImages = [];
  String? _selectedGovernorate;
  String? _selectedDistrict;
  String? _selectedCurrency;
  String _openTime = '08:00';
  String _closeTime = '23:00';
  bool _isLoadingLocations = true;
  bool _isSaving = false;
  String? _locationsError;

  bool get _isEditing => widget.field != null;

  @override
  void initState() {
    super.initState();
    final field = widget.field;
    if (field != null) {
      _nameController.text = field.name;
      _fieldCodeController.text = field.fieldCode;
      _descriptionController.text = field.description;
      _addressController.text = field.address;
      _priceController.text = field.pricePerHour.toString();
      _ownerPhoneController.text = field.ownerPhone ?? '';
      _selectedGovernorate = field.governorate;
      _selectedDistrict = field.district;
      _selectedCurrency = field.currency;
      _openTime = field.openTime;
      _closeTime = field.closeTime;
      _existingImages = List.of(field.images);
    }
    _loadLocations();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fieldCodeController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    _ownerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      final content = await rootBundle.loadString(AppConstants.locationsAssetPath);
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic> || decoded['governorates'] is! List<dynamic>) {
        throw const FormatException('تنسيق بيانات المحافظات غير صالح.');
      }

      final governorates = (decoded['governorates'] as List<dynamic>).map((item) {
        if (item is! Map<String, dynamic> || item['name'] is! String || item['districts'] is! List<dynamic>) {
          throw const FormatException('تعذر قراءة بيانات المحافظة.');
        }
        return {
          'name': item['name'] as String,
          'districts': List<String>.from(item['districts'] as List<dynamic>),
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _governorates = governorates;
        final selected = governorates.where((item) => item['name'] == _selectedGovernorate);
        if (selected.isNotEmpty) {
          _districts = List<String>.from(selected.first['districts'] as List);
          if (!_districts.contains(_selectedDistrict)) {
            _selectedDistrict = null;
          }
        } else {
          _selectedGovernorate = null;
          _selectedDistrict = null;
        }
        _isLoadingLocations = false;
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _locationsError = error.message;
        _isLoadingLocations = false;
      });
    } on FlutterError {
      if (!mounted) return;
      setState(() {
        _locationsError = 'تعذر تحميل بيانات المحافظات من ملفات التطبيق.';
        _isLoadingLocations = false;
      });
    }
  }

  Future<void> _pickPhotos() async {
    final remaining = _maximumImages - _existingImages.length - _newPhotos.length;
    if (remaining <= 0) {
      _showMessage('يمكن إضافة $_maximumImages صور كحد أقصى.');
      return;
    }

    try {
      final files = await _picker.pickMultiImage(
        imageQuality: 80, 
        maxWidth: 1200,
        maxHeight: 1200,
      );
      
      final selectedFiles = files.take(remaining);
      final photos = <_PickedPhoto>[];
      for (final file in selectedFiles) {
        final bytes = await file.readAsBytes();
        photos.add(_PickedPhoto(file, bytes));
      }

      if (!mounted) return;
      setState(() => _newPhotos.addAll(photos));
      
      if (files.length > remaining) {
        _showMessage('أُضيفت أول $remaining صور فقط للوصول إلى الحد الأقصى.');
      }
    } on PlatformException {
      if (mounted) _showMessage('تعذر فتح معرض الصور. تأكد من منح صلاحية الوصول للمعرض.');
    } catch (e) {
      if (mounted) _showMessage('حدث خطأ أثناء قراءة الصور.');
    }
  }

  Future<void> _chooseTime({required bool opening}) async {
    final current = opening ? _openTime : _closeTime;
    final parts = current.split(':');
    final initialTime = TimeOfDay(hour: int.parse(parts.first), minute: int.parse(parts.last));
    final selected = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (selected == null || !mounted) return;

    final value = '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (opening) {
        _openTime = value;
      } else {
        _closeTime = value;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGovernorate == null || _selectedDistrict == null) {
      _showMessage('اختر المحافظة والحي.');
      return;
    }

    setState(() => _isSaving = true);
    final uploadedUrls = <String>[];
    final firestoreService = ref.read(firestoreServiceProvider);
    final collection = FirebaseFirestore.instance.collection('fields');
    final document = _isEditing ? collection.doc(widget.field!.fieldId) : collection.doc();

    try {
      final userSnapshot = await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).get();
      final latestUserData = userSnapshot.data();
      final latestIsActive = latestUserData?['isActive'] == true;
      final latestExpiry = (latestUserData?['subscriptionExpiry'] as Timestamp?)?.toDate();

      final subscriptionActive = latestIsActive &&
          latestExpiry != null &&
          latestExpiry.isAfter(DateTime.now());

      if (!subscriptionActive) {
        if (mounted) {
          _showMessage('عذراً، اشتراكك غير فعال أو منتهي. يرجى التجديد من صفحة الاشتراك.');
          setState(() => _isSaving = false);
        }
        return;
      }

      const imgbbApiKey = '4bb6c80644549babc1da1450fa65e744'; 
      
      for (var index = 0; index < _newPhotos.length; index++) {
        final photo = _newPhotos[index];
        final base64Image = base64Encode(photo.bytes);
        
        final response = await http.post(
          Uri.parse('https://api.imgbb.com/1/upload?key=$imgbbApiKey'),
          body: {'image': base64Image},
        );

        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(response.body);
          final imageUrl = jsonResponse['data']['url'];
          uploadedUrls.add(imageUrl);
        } else {
          throw Exception('فشل رفع الصورة. رمز الحالة: ${response.statusCode}');
        }
      }

      final field = FieldModel(
        fieldId: document.id,
        ownerId: widget.user.uid,
        name: _nameController.text.trim(),
        fieldCode: _fieldCodeController.text.trim(),
        description: _descriptionController.text.trim(),
        governorate: _selectedGovernorate!,
        district: _selectedDistrict!,
        address: _addressController.text.trim(),
        geoPoint: const GeoPoint(_defaultLat, _defaultLng),
        pricePerHour: double.parse(_priceController.text.trim()),
        currency: _selectedCurrency ?? 'USD',
        openTime: _openTime,
        closeTime: _closeTime,
        images: [..._existingImages, ...uploadedUrls],
        isActive: true,
        ownerSubscriptionExpiry: latestExpiry,
        createdAt: widget.field?.createdAt ?? DateTime.now(),
        ownerPhone: _ownerPhoneController.text.trim().isEmpty ? null : _ownerPhoneController.text.trim(),
      );

      if (_isEditing) {
        await firestoreService.updateDocument(
          collection: 'fields',
          documentId: document.id,
          data: field.toMap(),
        );
      } else {
        await firestoreService.createDocument(
          collection: 'fields',
          documentId: document.id,
          data: field.toMap(),
        );
      }

      if (!mounted) return;
      _showMessage('تم حفظ الملعب بنجاح وأصبح متاحاً للجميع.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        _showMessage('حدث خطأ أثناء حفظ الملعب: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
      appBar: AppBar(title: Text(_isEditing ? 'تعديل الملعب' : 'إضافة ملعب')),
      body: _isLoadingLocations
          ? const Center(child: CircularProgressIndicator())
          : _locationsError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_locationsError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _loadLocations,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : ResponsiveContent(
                  maxWidth: 800,
                  padding: EdgeInsets.zero,
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'اسم الملعب',
                            prefixIcon: Icon(Icons.sports_soccer),
                          ),
                          validator: (value) => (value?.trim().isEmpty ?? true) ? 'أدخل اسم الملعب.' : null,
                        ),
                        const SizedBox(height: 14),
                        // 🚀 حقل الكود الجديد (بحد أقصى 5 أرقام)
                        TextFormField(
                          controller: _fieldCodeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'معرف الملعب (كود للبحث)',
                            helperText: 'أدخل رقماً من 1 إلى 5 أرقام (مثال: 12345)',
                            prefixIcon: Icon(Icons.numbers),
                          ),
                          validator: (value) {
                            final code = value?.trim() ?? '';
                            if (code.isEmpty) return 'أدخل معرفاً للملعب.';
                            if (code.length > 5) return 'يجب ألا يتجاوز المعرف 5 أرقام.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _descriptionController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'وصف الملعب',
                            alignLabelWithHint: true,
                          ),
                          validator: (value) => (value?.trim().isEmpty ?? true) ? 'أدخل وصفاً للملعب.' : null,
                        ),
                        const SizedBox(height: 14),
                        
                        DropdownButtonFormField<String>(
                          value: _selectedCurrency,
                          decoration: const InputDecoration(
                            labelText: 'العملة',
                            prefixIcon: Icon(Icons.currency_exchange),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'USD', child: Text('دولار أمريكي (\$)')),
                            DropdownMenuItem(value: 'SYP', child: Text('ليرة سورية جديدة (ل.س)')),
                            DropdownMenuItem(value: 'TRY', child: Text('ليرة تركية (TL)')),
                          ],
                          onChanged: _isSaving ? null : (value) => setState(() => _selectedCurrency = value),
                          validator: (value) => value == null ? 'يجب اختيار العملة أولاً' : null,
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _priceController,
                          enabled: _selectedCurrency != null && !_isSaving,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                          decoration: InputDecoration(
                            labelText: 'السعر',
                            prefixIcon: const Icon(Icons.attach_money),
                            helperText: 'سعر الحجز لكل 90 دقيقة',
                            suffixText: _selectedCurrency == 'USD'
                                ? '\$'
                                : _selectedCurrency == 'SYP'
                                    ? 'ل.س'
                                    : _selectedCurrency == 'TRY'
                                        ? 'TL'
                                        : '',
                          ),
                          validator: (value) {
                            if (_selectedCurrency == null) return null;
                            final price = double.tryParse(value?.trim() ?? '');
                            if (price == null || !price.isFinite || price <= 0) {
                              return 'أدخل سعراً أكبر من صفر.';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: _selectedGovernorate,
                          decoration: const InputDecoration(
                            labelText: 'المحافظة',
                            prefixIcon: Icon(Icons.map_outlined),
                          ),
                          items: _governorates
                              .map((item) => DropdownMenuItem<String>(
                                    value: item['name'] as String,
                                    child: Text(item['name'] as String),
                                  ))
                              .toList(),
                          onChanged: _isSaving
                              ? null
                              : (value) {
                                  final governorate = _governorates.firstWhere((item) => item['name'] == value);
                                  setState(() {
                                    _selectedGovernorate = value;
                                    _districts = List<String>.from(governorate['districts'] as List);
                                    _selectedDistrict = null;
                                  });
                                },
                          validator: (value) => value == null ? 'اختر المحافظة.' : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: _selectedDistrict,
                          decoration: const InputDecoration(
                            labelText: 'الحي / المنطقة',
                            prefixIcon: Icon(Icons.location_city_outlined),
                          ),
                          items: _districts
                              .map((district) => DropdownMenuItem<String>(
                                    value: district,
                                    child: Text(district),
                                  ))
                              .toList(),
                          onChanged: _isSaving ? null : (value) => setState(() => _selectedDistrict = value),
                          validator: (value) => value == null ? 'اختر الحي أو المنطقة.' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'العنوان التفصيلي',
                            prefixIcon: Icon(Icons.place_outlined),
                          ),
                          validator: (value) => (value?.trim().isEmpty ?? true) ? 'أدخل العنوان التفصيلي.' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _ownerPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'رقم واتساب للتواصل (اختياري)',
                            helperText: 'سيظهر هذا الرقم للعملاء كوسيلة تواصل عامة.',
                            prefixIcon: Icon(Icons.chat_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('أوقات العمل', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSaving ? null : () => _chooseTime(opening: true),
                                icon: const Icon(Icons.login),
                                label: Text('يفتح $_openTime'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSaving ? null : () => _chooseTime(opening: false),
                                icon: const Icon(Icons.logout),
                                label: Text('يغلق $_closeTime'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'صور الملعب (${_existingImages.length + _newPhotos.length}/$_maximumImages)',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _isSaving ? null : _pickPhotos,
                              icon: const Icon(Icons.add_photo_alternate_outlined),
                              label: const Text('إضافة صور'),
                            ),
                          ],
                        ),
                        if (_existingImages.isNotEmpty || _newPhotos.isNotEmpty)
                          SizedBox(
                            height: 100,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                ..._existingImages.map(
                                  (url) => _ImagePreview(
                                    image: Image.network(
                                      url,
                                      width: 88,
                                      height: 88,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Container(
                                          width: 88,
                                          height: 88,
                                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 88,
                                        height: 88,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                      ),
                                    ),
                                    onRemove: _isSaving
                                        ? null
                                        : () => setState(() => _existingImages.remove(url)),
                                  ),
                                ),
                                ..._newPhotos.map(
                                  (photo) => _ImagePreview(
                                    image: Image.memory(
                                      photo.bytes,
                                      width: 88,
                                      height: 88,
                                      fit: BoxFit.cover,
                                    ),
                                    onRemove: _isSaving
                                        ? null
                                        : () => setState(() => _newPhotos.remove(photo)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                        SportsButton(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving ? null : Icons.save_outlined,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white), strokeWidth: 2),
                                )
                              : Text(_isEditing ? 'حفظ التعديلات' : 'حفظ الملعب'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _PickedPhoto {
  const _PickedPhoto(this.file, this.bytes);
  final XFile file;
  final Uint8List bytes;
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.image, required this.onRemove});

  final Widget image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 88, height: 88, child: image),
          ),
          PositionedDirectional(
            top: 2,
            end: 2,
            child: IconButton.filledTonal(
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 16),
              iconSize: 28,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}