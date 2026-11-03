import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/core/constants.dart';
import 'package:fattball/models/field_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/screens/owner/field_location_picker.dart';
import 'package:fattball/services/firestore_service.dart';
import 'package:fattball/widgets/responsive_scaffold.dart';
import 'package:fattball/widgets/sports_button.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

class FieldForm extends ConsumerStatefulWidget {
  const FieldForm({super.key, required this.user, this.field});

  final UserModel user;
  final FieldModel? field;

  @override
  ConsumerState<FieldForm> createState() => _FieldFormState();
}

class _FieldFormState extends ConsumerState<FieldForm> {
  static const _maximumImages = 6;
  static const _defaultLocation = LatLng(33.5138, 36.2763);

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _storage = FirebaseStorage.instance;
  final _nameController = TextEditingController();
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
  
  // متغيرات العملة
  String? _selectedCurrency; 

  String _openTime = '08:00';
  String _closeTime = '23:00';
  LatLng _location = _defaultLocation;
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
      _descriptionController.text = field.description;
      _addressController.text = field.address;
      _priceController.text = field.pricePerHour.toString();
      _ownerPhoneController.text = field.ownerPhone ?? '';
      _selectedGovernorate = field.governorate;
      _selectedDistrict = field.district;
      _selectedCurrency = field.currency; // جلب العملة المحفوظة مسبقاً
      _openTime = field.openTime;
      _closeTime = field.closeTime;
      _location = LatLng(field.geoPoint.latitude, field.geoPoint.longitude);
      _existingImages = List.of(field.images);
    }
    _loadLocations();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    _ownerPhoneController.dispose();
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
          'districts': List<String>.from(item['districts'] as List<dynamic>),
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _governorates = governorates;
        final selected = governorates.where(
          (item) => item['name'] == _selectedGovernorate,
        );
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
    final remaining =
        _maximumImages - _existingImages.length - _newPhotos.length;
    if (remaining <= 0) {
      _showMessage('يمكن إضافة $_maximumImages صور كحد أقصى.');
      return;
    }

    try {
      final files = await _picker.pickMultiImage(
        imageQuality: 82,
        maxWidth: 1600,
      );
      final selectedFiles = files.take(remaining);
      final photos = <_PickedPhoto>[];
      for (final file in selectedFiles) {
        photos.add(_PickedPhoto(file, await file.readAsBytes()));
      }

      if (!mounted) return;
      setState(() => _newPhotos.addAll(photos));
      if (files.length > remaining) {
        _showMessage('أُضيفت أول $remaining صور فقط للوصول إلى الحد الأقصى.');
      }
    } on PlatformException {
      if (mounted) _showMessage('تعذر فتح معرض الصور.');
    } on FirebaseException {
      if (mounted) _showMessage('تعذر قراءة الصور المحددة.');
    }
  }

  Future<void> _chooseLocation() async {
    final selected = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute<LatLng>(
        builder: (_) => FieldLocationPicker(initialLocation: _location),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _location = selected);
    }
  }

  Future<void> _chooseTime({required bool opening}) async {
    final current = opening ? _openTime : _closeTime;
    final parts = current.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts.first),
      minute: int.parse(parts.last),
    );
    final selected = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
    );
    if (selected == null || !mounted) return;

    final value = '${selected.hour.toString().padLeft(2, '0')}:'
        '${selected.minute.toString().padLeft(2, '0')}';
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
    final document =
        _isEditing ? collection.doc(widget.field!.fieldId) : collection.doc();

    try {
      for (var index = 0; index < _newPhotos.length; index++) {
        final photo = _newPhotos[index];
        final reference = _storage.ref().child(
              'fields/${document.id}/${DateTime.now().microsecondsSinceEpoch}_$index',
            );
        final metadata = SettableMetadata(
          contentType: photo.file.mimeType ?? 'image/jpeg',
          customMetadata: {'ownerId': widget.user.uid},
        );
        await reference.putData(photo.bytes, metadata);
        uploadedUrls.add(await reference.getDownloadURL());
      }

      final subscriptionExpiry = widget.user.subscriptionExpiry;
      final subscriptionActive = widget.user.isActive &&
          subscriptionExpiry != null &&
          subscriptionExpiry.isAfter(DateTime.now());
      
      final field = FieldModel(
        fieldId: document.id,
        ownerId: widget.user.uid,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        governorate: _selectedGovernorate!,
        district: _selectedDistrict!,
        address: _addressController.text.trim(),
        geoPoint: GeoPoint(_location.latitude, _location.longitude),
        pricePerHour: double.parse(_priceController.text.trim()),
        currency: _selectedCurrency ?? 'USD', // حفظ العملة المختارة
        openTime: _openTime,
        closeTime: _closeTime,
        images: [..._existingImages, ...uploadedUrls],
        isActive: subscriptionActive,
        ownerSubscriptionExpiry: subscriptionExpiry,
        createdAt: widget.field?.createdAt ?? DateTime.now(),
        ownerPhone: _ownerPhoneController.text.trim().isEmpty
            ? null
            : _ownerPhoneController.text.trim(),
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

      final removedImages = widget.field?.images
              .where((url) => !_existingImages.contains(url))
              .toList() ??
          [];
      var oldImageCleanupFailed = false;
      for (final url in removedImages) {
        try {
          await _storage.refFromURL(url).delete();
        } on FirebaseException {
          oldImageCleanupFailed = true;
        }
      }

      if (!mounted) return;
      if (oldImageCleanupFailed) {
        _showMessage('تم حفظ بيانات الملعب، لكن تعذر حذف بعض الصور القديمة.');
      }
      Navigator.of(context).pop(true);
    } on FirestoreServiceException catch (error) {
      final cleanupFailed = await _deleteUploadedImages(uploadedUrls);
      if (mounted) {
        _showMessage(
          cleanupFailed
              ? '${error.message} وتعذر حذف بعض الصور المرفوعة.'
              : error.message,
        );
      }
    } on FirebaseException catch (error) {
      final cleanupFailed = await _deleteUploadedImages(uploadedUrls);
      if (mounted) {
        _showMessage(
          cleanupFailed
              ? '${_storageErrorMessage(error.code)} وتعذر حذف بعض الصور المرفوعة.'
              : _storageErrorMessage(error.code),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _deleteUploadedImages(List<String> urls) async {
    var failed = false;
    for (final url in urls) {
      try {
        await _storage.refFromURL(url).delete();
      } on FirebaseException {
        failed = true;
      }
    }
    return failed;
  }

  String _storageErrorMessage(String code) {
    return switch (code) {
      'unauthorized' ||
      'permission-denied' =>
        'ليست لديك صلاحية رفع الصور أو حذفها.',
      'canceled' => 'تم إلغاء رفع الصور.',
      'retry-limit-exceeded' => 'تعذر رفع الصورة بعد عدة محاولات.',
      'object-not-found' => 'تعذر العثور على الصورة المطلوبة.',
      _ => 'تعذر حفظ الصور. تحقق من الاتصال وحاول مجدداً.',
    };
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
        title: Text(_isEditing ? 'تعديل الملعب' : 'إضافة ملعب'),
      ),
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
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? 'أدخل اسم الملعب.'
                              : null,
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
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? 'أدخل وصفاً للملعب.'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        
                        // --- بداية التعديل: قائمة العملة ---
                        DropdownButtonFormField<String>(
                          value: _selectedCurrency,
                          decoration: const InputDecoration(
                            labelText: 'العملة',
                            prefixIcon: Icon(Icons.currency_exchange),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'USD',
                              child: Text('دولار أمريكي (\$)'),
                            ),
                            DropdownMenuItem(
                              value: 'SYP',
                              child: Text('ليرة سورية جديدة (ل.س)'),
                            ),
                            DropdownMenuItem(
                              value: 'TRY',
                              child: Text('ليرة تركية (TL)'),
                            ),
                          ],
                          onChanged: _isSaving
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedCurrency = value;
                                  });
                                },
                          validator: (value) => value == null
                              ? 'يجب اختيار العملة أولاً'
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // --- التعديل: حقل السعر ---
                        TextFormField(
                          controller: _priceController,
                          enabled: _selectedCurrency != null && !_isSaving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: 'السعر',
                            prefixIcon: const Icon(Icons.attach_money),
                            helperText: 'سعر الحجز لكل 90 دقيقة', // النص التوضيحي
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
                            if (price == null ||
                                !price.isFinite ||
                                price <= 0) {
                              return 'أدخل سعراً أكبر من صفر.';
                            }
                            return null;
                          },
                        ),
                        // --- نهاية التعديل ---
                        
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: _selectedGovernorate,
                          decoration: const InputDecoration(
                            labelText: 'المحافظة',
                            prefixIcon: Icon(Icons.map_outlined),
                          ),
                          items: _governorates
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item['name'] as String,
                                  child: Text(item['name'] as String),
                                ),
                              )
                              .toList(),
                          onChanged: _isSaving
                              ? null
                              : (value) {
                                  final governorate = _governorates.firstWhere(
                                    (item) => item['name'] == value,
                                  );
                                  setState(() {
                                    _selectedGovernorate = value;
                                    _districts = List<String>.from(
                                      governorate['districts'] as List,
                                    );
                                    _selectedDistrict = null;
                                  });
                                },
                          validator: (value) =>
                              value == null ? 'اختر المحافظة.' : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: _selectedDistrict,
                          decoration: const InputDecoration(
                            labelText: 'الحي / المنطقة',
                            prefixIcon: Icon(Icons.location_city_outlined),
                          ),
                          items: _districts
                              .map(
                                (district) => DropdownMenuItem<String>(
                                  value: district,
                                  child: Text(district),
                                ),
                              )
                              .toList(),
                          onChanged: _isSaving
                              ? null
                              : (value) =>
                                  setState(() => _selectedDistrict = value),
                          validator: (value) =>
                              value == null ? 'اختر الحي أو المنطقة.' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'العنوان التفصيلي',
                            prefixIcon: Icon(Icons.place_outlined),
                          ),
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? 'أدخل العنوان التفصيلي.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _ownerPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'رقم واتساب للتواصل (اختياري)',
                            helperText:
                                'سيظهر هذا الرقم للعملاء كوسيلة تواصل عامة.',
                            prefixIcon: Icon(Icons.chat_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'أوقات العمل',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSaving
                                    ? null
                                    : () => _chooseTime(opening: true),
                                icon: const Icon(Icons.login),
                                label: Text('يفتح $_openTime'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSaving
                                    ? null
                                    : () => _chooseTime(opening: false),
                                icon: const Icon(Icons.logout),
                                label: Text('يغلق $_closeTime'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _chooseLocation,
                          icon: const Icon(Icons.map),
                          label: Text(
                            'تحديد الموقع على الخريطة'
                            ' (${_location.latitude.toStringAsFixed(5)}, '
                            '${_location.longitude.toStringAsFixed(5)})',
                          ),
                        ),
                        const SizedBox(height: 16),
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
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                              ),
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
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image_outlined,
                                      ),
                                    ),
                                    onRemove: _isSaving
                                        ? null
                                        : () => setState(
                                              () => _existingImages.remove(url),
                                            ),
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
                                        : () => setState(
                                              () => _newPhotos.remove(photo),
                                            ),
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
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _isEditing ? 'حفظ التعديلات' : 'حفظ الملعب',
                                ),
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