import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/booking_model.dart';
import 'package:fattball/models/coach_model.dart';
import 'package:fattball/models/field_model.dart';
import 'package:fattball/models/promo_code_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/services/booking_service.dart';
import 'package:fattball/services/promo_code_service.dart';
import 'package:fattball/widgets/booking_slot_picker.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:fattball/widgets/responsive_scaffold.dart';
import 'package:fattball/widgets/weather_widgets.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({
    super.key,
    required this.field,
    required this.customer,
    this.coach,
  });

  final FieldModel field;
  final UserModel customer;
  final CoachModel? coach;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  late final timezone.Location _damascus;
  DateTimeRange? _selectedSlot;
  final _imagePicker = ImagePicker();
  final _promoController = TextEditingController();
  final _childNameController = TextEditingController();
  final _childAgeController = TextEditingController();
  XFile? _depositReceipt;
  Uint8List? _depositReceiptBytes;
  PromoCodeModel? _appliedPromo;
  bool _isCheckingPromo = false;
  bool _depositRequired = false;
  bool _cashPaymentConfirmed = false;
  String _depositMethod = 'cash';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    timezone_data.initializeTimeZones();
    _damascus = timezone.getLocation('Asia/Damascus');
  }

  @override
  void dispose() {
    _promoController.dispose();
    _childNameController.dispose();
    _childAgeController.dispose();
    super.dispose();
  }

  Future<void> _applyPromoCode() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) {
      _showMessage('أدخل كود الخصم أولاً.');
      return;
    }

    setState(() => _isCheckingPromo = true);
    try {
      final promo = await ref.read(promoCodeServiceProvider).validatePromoCode(
            fieldId: widget.field.fieldId,
            ownerId: widget.field.ownerId,
            code: code,
          );
      if (!mounted) return;
      setState(() => _appliedPromo = promo);
      _showMessage('تم تطبيق خصم ${promo.discountPercent}% بنجاح.');
    } on PromoCodeServiceException catch (error) {
      if (mounted) {
        setState(() => _appliedPromo = null);
        _showMessage(error.message);
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() => _appliedPromo = null);
        _showMessage(error.message);
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        setState(() => _appliedPromo = null);
        _showMessage(
          error.code == 'permission-denied'
              ? 'لا يمكن التحقق من كود الخصم لهذا الملعب.'
              : 'تعذر التحقق من الكود. تحقق من الاتصال وحاول مجدداً.',
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingPromo = false);
    }
  }

  Future<void> _submit() async {
    final slot = _selectedSlot;
    if (slot == null) {
      _showMessage('اختر الفترة التي تريد حجزها أولاً.');
      return;
    }
    final childName = _childNameController.text.trim();
    final childAge = int.tryParse(_childAgeController.text.trim());
    if (widget.coach != null &&
        (childName.length < 2 ||
            childName.length > 60 ||
            childAge == null ||
            childAge < 3 ||
            childAge > 17)) {
      _showMessage('أدخل الاسم الأول للطفل وعمره بين 3 و17 سنة.');
      return;
    }
    if (_depositRequired &&
        _depositMethod == 'cash' &&
        !_cashPaymentConfirmed) {
      _showMessage('أكد تسليم العربون نقداً قبل إرسال الطلب.');
      return;
    }
    if (_depositRequired &&
        _depositMethod != 'cash' &&
        _depositReceipt == null) {
      _showMessage('ارفع صورة إشعار التحويل لإرسال طلب العربون.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحجز'),
        content: Text(
          'هل تريد إرسال طلب حجز من ${_formatTime(slot.start)} '
          'إلى ${_formatTime(slot.end)}؟'
          '${_appliedPromo == null ? '' : '\n\nالإجمالي بعد الخصم: ${_bookingTotal.toStringAsFixed(2)} USD'}'
          '${widget.coach == null ? '' : '\n\nجلسة تدريب مع ${widget.coach!.name} للطفل $childName، عمر $childAge سنة.'}'
          '${_depositRequired ? '\n\nالعربون المطلوب: ${(_bookingTotal * 0.2).toStringAsFixed(2)} USD' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final receiptUrl = _depositRequired && _depositMethod != 'cash'
          ? await _uploadDepositReceipt()
          : null;
      final result = await ref.read(bookingServiceProvider).createBooking(
            field: widget.field,
            customer: widget.customer,
            startAt: slot.start,
            endAt: slot.end,
            depositRequired: _depositRequired,
            depositMethod: _depositRequired ? _depositMethod : null,
            depositReceiptUrl: receiptUrl,
            promoCode: _appliedPromo?.code,
            coach: widget.coach,
            trainingChildName: widget.coach == null ? null : childName,
            trainingChildAge: widget.coach == null ? null : childAge,
          );

      if (!mounted) return;
      switch (result) {
        case BookingCreated():
          _showMessage(
            _depositRequired
                ? 'تم إرسال إثبات العربون. يبقى الحجز بانتظار موافقة صاحب الملعب.'
                : 'تم إرسال طلب الحجز بنجاح.',
          );
          Navigator.of(context).pop();
        case BookingConflict(:final message):
          _showMessage(message);
        case BookingRejected(:final message):
          _showMessage(message);
      }
    } on BookingServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    } on FirebaseException catch (error) {
      if (mounted) {
        _showMessage(
          error.code == 'permission-denied'
              ? 'تعذر رفع إثبات العربون بسبب إعدادات الصلاحيات.'
              : 'تعذر رفع إثبات العربون. تحقق من الاتصال وحاول مجدداً.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<String> _uploadDepositReceipt() async {
    final receipt = _depositReceipt;
    if (receipt == null || _depositReceiptBytes == null) {
      throw const BookingServiceException('اختر صورة إشعار التحويل أولاً.');
    }
    final mimeType = receipt.mimeType ?? 'image/jpeg';
    final extension = switch (mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final receiptId =
        FirebaseFirestore.instance.collection('bookings').doc().id;
    final reference = FirebaseStorage.instance.ref().child(
          'deposit_receipts/${widget.field.fieldId}/${widget.customer.uid}/'
          '$receiptId.$extension',
        );
    await reference.putData(
      _depositReceiptBytes!,
      SettableMetadata(
        contentType: mimeType,
        customMetadata: {
          'customerId': widget.customer.uid,
          'fieldId': widget.field.fieldId,
        },
      ),
    );
    return reference.getDownloadURL();
  }

  Future<void> _pickDepositReceipt() async {
    try {
      final receipt = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
      );
      if (receipt == null) return;
      final bytes = await receipt.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        _showMessage('حجم صورة الإيصال يجب ألا يتجاوز 5 ميغابايت.');
        return;
      }
      if (mounted) {
        setState(() {
          _depositReceipt = receipt;
          _depositReceiptBytes = bytes;
        });
      }
    } on PlatformException {
      if (mounted) _showMessage('تعذر فتح معرض الصور لاختيار الإيصال.');
    }
  }

  double get _bookingSubtotal {
    final slot = _selectedSlot;
    if (slot == null) return 0;
    final hourlyRate =
        widget.field.pricePerHour + (widget.coach?.pricePerHour ?? 0);
    return hourlyRate * slot.duration.inMinutes / 60;
  }

  double get _discountAmount {
    return _bookingSubtotal - _bookingTotal;
  }

  double get _bookingTotal {
    final percent = _appliedPromo?.discountPercent ?? 0;
    return (_bookingSubtotal * (100 - percent) / 100 * 100).round() / 100;
  }

  String _formatTime(DateTime time) {
    final local = timezone.TZDateTime.from(time, _damascus);
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    final local = timezone.TZDateTime.from(date, _damascus);
    return '${local.year.toString().padLeft(4, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')}';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(glassSnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bookingsStream = FirebaseFirestore.instance
        .collection('booking_locks')
        .where('fieldId', isEqualTo: widget.field.fieldId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('اختيار موعد الحجز')),
      body: ResponsiveContent(
        maxWidth: 900,
        padding: EdgeInsets.zero,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: bookingsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _readError(snapshot.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<BookingModel> bookings;
            try {
              bookings = _bookingsFromLocks(snapshot.data?.docs ?? []);
            } on FormatException {
              return const Center(
                child: Text('توجد بيانات موعد غير صالحة لهذا الملعب.'),
              );
            } on TypeError {
              return const Center(
                child: Text('توجد بيانات موعد غير مكتملة لهذا الملعب.'),
              );
            } on ArgumentError {
              return const Center(
                child: Text('توجد حالة موعد غير معروفة لهذا الملعب.'),
              );
            }

            final total = _selectedSlot == null ? null : _bookingTotal;

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.field.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.field.governorate} - ${widget.field.district}',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.field.pricePerHour.toStringAsFixed(2)} USD / ساعة',
                        ),
                        if (widget.coach != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'التدريب مع ${widget.coach!.name}: '
                            '${widget.coach!.pricePerHour.toStringAsFixed(2)} USD / ساعة',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (widget.coach != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'بيانات جلسة التدريب',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'أدخل الاسم الأول للطفل فقط. ستُرسل هذه البيانات لصاحب الملعب لإتمام الجلسة.',
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _childNameController,
                            enabled: !_isSubmitting,
                            maxLength: 60,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'الاسم الأول للطفل',
                              prefixIcon: Icon(Icons.child_care_outlined),
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _childAgeController,
                            enabled: !_isSubmitting,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'العمر (3–17 سنة)',
                              prefixIcon: Icon(Icons.cake_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'اختر موعداً متاحاً',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                BookingSlotPicker(
                  field: widget.field,
                  bookings: bookings,
                  onSlotSelected: (slot) =>
                      setState(() => _selectedSlot = slot),
                ),
                if (_selectedSlot != null && total != null) ...[
                  Card(
                    child: BookingWeatherAlert(
                      field: widget.field,
                      startAt: _selectedSlot!.start,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_outlined),
                      title: Text(
                        '${_formatDate(_selectedSlot!.start)} — '
                        '${_formatTime(_selectedSlot!.start)} إلى '
                        '${_formatTime(_selectedSlot!.end)}',
                      ),
                      subtitle: Text(
                        _appliedPromo == null
                            ? 'الإجمالي: ${total.toStringAsFixed(2)} USD'
                            : 'قبل الخصم: ${_bookingSubtotal.toStringAsFixed(2)} USD'
                                '\nخصم ${_appliedPromo!.discountPercent}% '
                                '(${_discountAmount.toStringAsFixed(2)} USD)'
                                '\nالإجمالي: ${total.toStringAsFixed(2)} USD',
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _promoController,
                            enabled: !_isSubmitting && !_isCheckingPromo,
                            textCapitalization: TextCapitalization.characters,
                            textDirection: TextDirection.ltr,
                            maxLength: 20,
                            decoration: InputDecoration(
                              labelText: 'كود الخصم',
                              hintText: 'FOOTBALL10',
                              counterText: '',
                              prefixIcon:
                                  const Icon(Icons.local_offer_outlined),
                              suffixIcon: _appliedPromo == null
                                  ? null
                                  : IconButton(
                                      tooltip: 'إزالة كود الخصم',
                                      onPressed: _isSubmitting
                                          ? null
                                          : () => setState(() {
                                                _appliedPromo = null;
                                                _promoController.clear();
                                              }),
                                      icon: const Icon(Icons.close),
                                    ),
                            ),
                            onChanged: (_) {
                              if (_appliedPromo != null) {
                                setState(() => _appliedPromo = null);
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _isSubmitting || _isCheckingPromo
                                ? null
                                : _appliedPromo != null
                                    ? null
                                    : _applyPromoCode,
                            icon: _isCheckingPromo
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _appliedPromo == null
                                        ? Icons.check_circle_outline
                                        : Icons.verified_outlined,
                                  ),
                            label: Text(
                              _appliedPromo == null
                                  ? 'تطبيق كود الخصم'
                                  : 'تم تطبيق ${_appliedPromo!.discountPercent}% خصم',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _depositRequired,
                          onChanged: _isSubmitting
                              ? null
                              : (value) => setState(() {
                                    _depositRequired = value;
                                    _cashPaymentConfirmed = false;
                                    _depositReceipt = null;
                                    _depositReceiptBytes = null;
                                  }),
                          title: const Text('دفع عربون لتأكيد الحجز'),
                          subtitle: Text(
                            'عربون 20%: ${(total * 0.2).toStringAsFixed(2)} USD',
                          ),
                          secondary: const Icon(Icons.verified_user_outlined),
                        ),
                        if (_depositRequired) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'اختر طريقة دفع العربون. لا تتم أي عملية دفع إلكترونية داخل التطبيق.',
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _depositMethod,
                                  decoration: const InputDecoration(
                                    labelText: 'طريقة الدفع',
                                    prefixIcon: Icon(Icons.payments_outlined),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'cash',
                                      child: Text('نقداً لصاحب الملعب'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'sham_cash',
                                      child: Text('شام كاش'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'syriatel_cash',
                                      child: Text('سيرياتيل كاش'),
                                    ),
                                  ],
                                  onChanged: _isSubmitting
                                      ? null
                                      : (value) {
                                          if (value == null) return;
                                          setState(() {
                                            _depositMethod = value;
                                            _cashPaymentConfirmed = false;
                                            _depositReceipt = null;
                                            _depositReceiptBytes = null;
                                          });
                                        },
                                ),
                                const SizedBox(height: 8),
                                if (_depositMethod == 'cash')
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: _cashPaymentConfirmed,
                                    onChanged: _isSubmitting
                                        ? null
                                        : (value) => setState(
                                              () => _cashPaymentConfirmed =
                                                  value ?? false,
                                            ),
                                    title: const Text(
                                      'أؤكد تسليم العربون نقداً لصاحب الملعب.',
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  )
                                else ...[
                                  const Text(
                                    'تواصل مع صاحب الملعب لمعرفة تفاصيل التحويل، ثم ارفع صورة الإشعار.',
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: _isSubmitting
                                        ? null
                                        : _pickDepositReceipt,
                                    icon:
                                        const Icon(Icons.upload_file_outlined),
                                    label: Text(
                                      _depositReceipt == null
                                          ? 'اختيار صورة الإشعار'
                                          : 'تغيير صورة الإشعار',
                                    ),
                                  ),
                                  if (_depositReceiptBytes != null) ...[
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        _depositReceiptBytes!,
                                        height: 150,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _isSubmitting || _selectedSlot == null ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline),
          label: const Text('إرسال طلب الحجز'),
        ),
      ),
    );
  }

  String _readError(Object? error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => 'ليست لديك صلاحية عرض المواعيد المتاحة.',
        'unavailable' => 'الخدمة غير متاحة حالياً. تحقق من اتصالك.',
        'failed-precondition' =>
          'تعذر تحميل الحجوزات؛ قد يتطلب الأمر إنشاء فهرس Firestore.',
        _ => 'تعذر تحميل المواعيد. يرجى المحاولة مجدداً.',
      };
    }
    return 'تعذر تحميل المواعيد. يرجى المحاولة مجدداً.';
  }

  List<BookingModel> _bookingsFromLocks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    final bookings = <BookingModel>[];
    for (final document in documents) {
      final lockData = document.data();
      final fieldId = lockData['fieldId'];
      final ownerId = lockData['ownerId'];
      final rawReservations = lockData['reservations'];
      if (fieldId is! String || ownerId is! String || rawReservations is! Map) {
        throw const FormatException('قفل مواعيد الملعب غير صالح.');
      }

      for (final rawReservation in rawReservations.values) {
        if (rawReservation is! Map) {
          throw const FormatException('بيانات الموعد المحجوز غير صالحة.');
        }
        final reservation = Map<String, dynamic>.from(rawReservation);
        final bookingId = reservation['bookingId'];
        final startAt = reservation['startAt'];
        final endAt = reservation['endAt'];
        final statusValue = reservation['status'];
        if (bookingId is! String ||
            startAt is! Timestamp ||
            endAt is! Timestamp ||
            statusValue is! String) {
          throw const FormatException('بيانات الموعد المحجوز غير مكتملة.');
        }

        bookings.add(
          BookingModel(
            bookingId: bookingId,
            fieldId: fieldId,
            ownerId: ownerId,
            customerId: '',
            customerName: '',
            startAt: startAt.toDate(),
            endAt: endAt.toDate(),
            status: BookingStatus.values.byName(statusValue),
            totalPrice: 0,
            createdAt: startAt.toDate(),
          ),
        );
      }
    }
    return bookings;
  }
}
