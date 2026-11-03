import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/core/constants.dart';
import 'package:fattball/models/booking_model.dart';
import 'package:fattball/models/coach_model.dart';
import 'package:fattball/models/field_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

sealed class BookingResult {
  const BookingResult();
}

class BookingCreated extends BookingResult {
  const BookingCreated(this.booking);

  final BookingModel booking;
}

class BookingConflict extends BookingResult {
  const BookingConflict()
      : message = 'هذا الموعد محجوز بالفعل. اختر موعداً آخر.';

  final String message;
}

class BookingRejected extends BookingResult {
  const BookingRejected(this.message);

  final String message;
}

class BookingServiceException implements Exception {
  const BookingServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BookingService {
  BookingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'me-central1') {
    _initializeTimeZones();
  }

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  static bool _timeZonesInitialized = false;

  static void _initializeTimeZones() {
    if (_timeZonesInitialized) return;
    timezone_data.initializeTimeZones();
    _timeZonesInitialized = true;
  }

  timezone.Location get _damascusLocation =>
      timezone.getLocation(AppConstants.timeZone);

  Future<BookingResult> createBooking({
    required FieldModel field,
    required UserModel customer,
    required DateTime startAt,
    required DateTime endAt,
    bool depositRequired = false,
    String? depositMethod,
    String? depositReceiptUrl,
    String? promoCode,
    CoachModel? coach,
    String? trainingChildName,
    int? trainingChildAge,
  }) async {
    if (customer.role != 'customer' || !customer.isActive) {
      return const BookingRejected('هذا الحساب غير مخوّل لإنشاء حجز.');
    }
    if (_auth.currentUser?.uid != customer.uid) {
      return const BookingRejected('سجّل الدخول بحساب العميل لإنشاء الحجز.');
    }
    if (coach == null) {
      if (trainingChildName != null || trainingChildAge != null) {
        return const BookingRejected('بيانات جلسة التدريب غير متوافقة.');
      }
    } else {
      final childName = trainingChildName?.trim() ?? '';
      if (coach.fieldId != field.fieldId ||
          coach.ownerId != field.ownerId ||
          childName.length < 2 ||
          childName.length > 60 ||
          trainingChildAge == null ||
          trainingChildAge < 3 ||
          trainingChildAge > 17) {
        return const BookingRejected(
          'تحقق من اختيار المدرب واسم الطفل وعمره (3–17 سنة).',
        );
      }
    }

    final startUtc = startAt.toUtc();
    final endUtc = endAt.toUtc();
    final now = DateTime.now().toUtc();
    if (!startUtc.isAfter(now) || !endUtc.isAfter(startUtc)) {
      return const BookingRejected('وقت الحجز غير صالح أو أصبح في الماضي.');
    }

    final dayKeys = _dayKeys(startUtc, endUtc);
    final bookingRef = _firestore.collection('bookings').doc();
    final fieldRef = _firestore.collection('fields').doc(field.fieldId);
    final coachRef = coach == null
        ? null
        : fieldRef.collection('coaches').doc(coach.coachId);
    final customerRef = _firestore.collection('users').doc(customer.uid);
    final lockRefs = dayKeys
        .map(
          (dayKey) => _firestore
              .collection('booking_locks')
              .doc('${field.fieldId}_$dayKey'),
        )
        .toList();

    try {
      // The public daily lock contains only availability data; booking documents
      // remain private to their customer and the field owner.
      final result = await _firestore.runTransaction<BookingResult>(
        (transaction) async {
          final fieldSnapshot = await transaction.get(fieldRef);
          final customerSnapshot = await transaction.get(customerRef);
          final coachSnapshot =
              coachRef == null ? null : await transaction.get(coachRef);
          final lockSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
          for (final lockRef in lockRefs) {
            lockSnapshots.add(await transaction.get(lockRef));
          }

          final fieldData = fieldSnapshot.data();
          if (fieldData == null) {
            return const BookingRejected('الملعب المطلوب غير موجود.');
          }
          if (fieldData['ownerId'] != field.ownerId) {
            return const BookingRejected('بيانات مالك الملعب غير صالحة.');
          }
          if (fieldData['isActive'] != true) {
            return const BookingRejected('هذا الملعب غير متاح للحجز حالياً.');
          }

          final rawExpiry = fieldData['ownerSubscriptionExpiry'];
          final expiry = rawExpiry is Timestamp ? rawExpiry.toDate() : null;
          if (expiry == null || !expiry.isAfter(DateTime.now())) {
            return const BookingRejected('اشتراك هذا الملعب غير فعّال حالياً.');
          }
          if (!customerSnapshot.exists ||
              customerSnapshot.data()?['isActive'] != true) {
            return const BookingRejected('حساب العميل غير فعّال.');
          }

          final coachData = coachSnapshot?.data();
          var coachPricePerHour = 0.0;
          if (coach != null) {
            final price = coachData?['pricePerHour'];
            if (coachData == null ||
                coachData['fieldId'] != field.fieldId ||
                coachData['ownerId'] != field.ownerId ||
                coachData['isActive'] != true ||
                price is! num ||
                !price.isFinite ||
                price <= 0 ||
                coachData['name'] is! String) {
              return const BookingRejected(
                'هذا المدرب لم يعد متاحاً. اختر مدرباً آخر.',
              );
            }
            coachPricePerHour = price.toDouble();
          }

          for (final lockSnapshot in lockSnapshots) {
            final reservations =
                lockSnapshot.data()?['reservations'] as Map<String, dynamic>?;
            if (reservations == null) continue;

            for (final reservation in reservations.values) {
              if (reservation is! Map<String, dynamic>) {
                throw const BookingServiceException(
                  'بيانات قفل المواعيد غير صالحة.',
                );
              }
              if (_isOverlappingReservation(
                reservation,
                startUtc,
                endUtc,
              )) {
                return const BookingConflict();
              }
            }
          }

          final priceValue = fieldData['pricePerHour'];
          if (priceValue is! num || !priceValue.isFinite || priceValue <= 0) {
            throw const BookingServiceException(
              'سعر الملعب المسجل غير صالح.',
            );
          }
          final subtotalPrice = (priceValue.toDouble() + coachPricePerHour) *
              endUtc.difference(startUtc).inMinutes /
              60;
          String? appliedPromoCode;
          var discountPercent = 0;
          if (promoCode != null) {
            final normalizedCode =
                promoCode.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
            if (!RegExp(r'^[A-Z0-9]{4,20}$').hasMatch(normalizedCode)) {
              return const BookingRejected('صيغة كود الخصم غير صالحة.');
            }
            final promoRef =
                fieldRef.collection('promo_codes').doc(normalizedCode);
            final promoSnapshot = await transaction.get(promoRef);
            final promo = promoSnapshot.data();
            final now = DateTime.now();
            if (promo == null ||
                promo['fieldId'] != field.fieldId ||
                promo['ownerId'] != field.ownerId ||
                promo['code'] != normalizedCode ||
                promo['isActive'] != true ||
                promo['discountPercent'] is! int ||
                (promo['discountPercent'] as int) < 1 ||
                (promo['discountPercent'] as int) > 90 ||
                promo['startsAt'] is! Timestamp ||
                promo['expiresAt'] is! Timestamp ||
                (promo['startsAt'] as Timestamp).toDate().isAfter(now) ||
                !(promo['expiresAt'] as Timestamp).toDate().isAfter(now)) {
              return const BookingRejected(
                'كود الخصم منتهي الصلاحية أو غير صالح لهذا الملعب.',
              );
            }
            appliedPromoCode = normalizedCode;
            discountPercent = promo['discountPercent'] as int;
          }
          final totalPrice = _roundCurrency(
            subtotalPrice * (100 - discountPercent) / 100,
          );
          if (depositRequired) {
            if (!const {'cash', 'sham_cash', 'syriatel_cash'}
                .contains(depositMethod)) {
              return const BookingRejected('اختر طريقة دفع عربون صالحة.');
            }
            final isWalletPayment = depositMethod == 'sham_cash' ||
                depositMethod == 'syriatel_cash';
            if (isWalletPayment &&
                (depositReceiptUrl == null ||
                    !depositReceiptUrl.startsWith(
                      'https://firebasestorage.googleapis.com/',
                    ))) {
              return const BookingRejected(
                'ارفع صورة إشعار التحويل قبل إرسال طلب الحجز.',
              );
            }
            if (!isWalletPayment && depositReceiptUrl != null) {
              return const BookingRejected(
                'لا حاجة لإرفاق إيصال عند تسليم العربون نقداً.',
              );
            }
          } else if (depositMethod != null || depositReceiptUrl != null) {
            return const BookingRejected('بيانات العربون غير متوافقة.');
          }
          final currentField = FieldModel.fromMap(
            field.fieldId,
            fieldData,
          );
          final booking = BookingModel(
            bookingId: bookingRef.id,
            fieldId: field.fieldId,
            ownerId: field.ownerId,
            customerId: customer.uid,
            customerName: customer.name,
            startAt: startUtc,
            endAt: endUtc,
            status: BookingStatus.pending,
            totalPrice: totalPrice,
            createdAt: DateTime.now().toUtc(),
            subtotalPrice: subtotalPrice,
            promoCode: appliedPromoCode,
            discountPercent: discountPercent,
            depositRequired: depositRequired,
            depositAmount: depositRequired ? totalPrice * 0.2 : 0,
            depositMethod: depositRequired ? depositMethod : null,
            depositReceiptUrl: depositRequired ? depositReceiptUrl : null,
            depositStatus:
                depositRequired ? 'pending_approval' : 'not_required',
            coachId: coach?.coachId,
            coachName: coach == null ? null : coachData!['name'] as String,
            trainingChildName: coach == null ? null : trainingChildName!.trim(),
            trainingChildAge: coach == null ? null : trainingChildAge,
            coachPricePerHour: coachPricePerHour,
          );
          final bookingData = booking.toMap();
          final reservation = {
            'bookingId': booking.bookingId,
            'startAt': Timestamp.fromDate(startUtc),
            'endAt': Timestamp.fromDate(endUtc),
            'status': BookingStatus.pending.name,
          };

          transaction.set(bookingRef, bookingData);
          for (var index = 0; index < lockRefs.length; index++) {
            final existingReservations =
                lockSnapshots[index].data()?['reservations'];
            final reservations = existingReservations == null
                ? <String, dynamic>{}
                : Map<String, dynamic>.from(
                    existingReservations as Map<dynamic, dynamic>,
                  );
            reservations[booking.bookingId] = reservation;
            transaction.set(
              lockRefs[index],
              {
                'fieldId': field.fieldId,
                'ownerId': currentField.ownerId,
                'bookingId': booking.bookingId,
                'reservations': reservations,
              },
              SetOptions(merge: true),
            );
          }
          return BookingCreated(booking);
        },
      );
      return result;
    } on BookingServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw BookingServiceException(_firebaseErrorMessage(error.code));
    } on FormatException {
      throw const BookingServiceException(
        'بيانات الملعب غير مكتملة أو غير صالحة.',
      );
    } on TypeError {
      throw const BookingServiceException(
        'بيانات الحجز أو الملعب غير متوافقة مع المخطط المطلوب.',
      );
    }
  }

  Future<void> updateBookingStatus({
    required String bookingId,
    required String ownerId,
    required BookingStatus status,
  }) async {
    if (status != BookingStatus.confirmed &&
        status != BookingStatus.cancelled &&
        status != BookingStatus.completed) {
      throw const BookingServiceException(
        'الحالة المطلوبة غير مسموح بها من لوحة صاحب الملعب.',
      );
    }
    if (_auth.currentUser?.uid != ownerId) {
      throw const BookingServiceException(
        'سجّل الدخول بحساب صاحب الملعب لتنفيذ هذا الإجراء.',
      );
    }

    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    try {
      await _firestore.runTransaction<void>((transaction) async {
        final bookingSnapshot = await transaction.get(bookingRef);
        final bookingData = bookingSnapshot.data();
        if (bookingData == null) {
          throw const BookingServiceException('الحجز المطلوب غير موجود.');
        }
        if (bookingData['ownerId'] != ownerId) {
          throw const BookingServiceException(
            'هذا الحجز لا يتبع حسابك.',
          );
        }

        final currentStatus = bookingData['status'];
        if (currentStatus == status.name) return;
        if (currentStatus != BookingStatus.pending.name &&
            !(status == BookingStatus.cancelled &&
                currentStatus == BookingStatus.confirmed.name) &&
            !(status == BookingStatus.completed &&
                currentStatus == BookingStatus.confirmed.name)) {
          throw const BookingServiceException(
            'لا يمكن تغيير حالة هذا الحجز.',
          );
        }

        final startAt = bookingData['startAt'];
        final endAt = bookingData['endAt'];
        final fieldId = bookingData['fieldId'];
        if (startAt is! Timestamp ||
            endAt is! Timestamp ||
            fieldId is! String) {
          throw const BookingServiceException(
            'بيانات وقت الحجز أو الملعب غير صالحة.',
          );
        }

        final start = startAt.toDate();
        final end = endAt.toDate();
        if (status == BookingStatus.completed &&
            end.isAfter(DateTime.now().toUtc())) {
          throw const BookingServiceException(
            'لا يمكن إكمال الحجز قبل انتهاء موعده.',
          );
        }
        final lockRefs = _dayKeys(start, end)
            .map(
              (dayKey) => _firestore
                  .collection('booking_locks')
                  .doc('${fieldId}_$dayKey'),
            )
            .toList();
        final lockSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final lockRef in lockRefs) {
          lockSnapshots.add(await transaction.get(lockRef));
        }

        final depositRequired = bookingData['depositRequired'] == true;
        if (depositRequired &&
            status == BookingStatus.confirmed &&
            bookingData['depositStatus'] != 'pending_approval') {
          throw const BookingServiceException(
            'حالة العربون لا تسمح بتأكيد هذا الحجز.',
          );
        }
        final update = <String, Object?>{'status': status.name};
        if (depositRequired && currentStatus == BookingStatus.pending.name) {
          update['depositStatus'] =
              status == BookingStatus.confirmed ? 'approved' : 'rejected';
        }
        transaction.update(bookingRef, update);
        for (var index = 0; index < lockRefs.length; index++) {
          final lockData = lockSnapshots[index].data();
          if (lockData == null) continue;
          final rawReservations = lockData['reservations'];
          if (rawReservations is! Map) {
            throw const BookingServiceException(
              'بيانات قفل المواعيد غير صالحة.',
            );
          }

          final reservations = Map<String, dynamic>.from(rawReservations);
          final rawReservation = reservations[bookingId];
          if (rawReservation is! Map) continue;
          final reservation = Map<String, dynamic>.from(rawReservation);
          reservation['status'] = status.name;
          reservations[bookingId] = reservation;
          transaction.set(
            lockRefs[index],
            {
              'bookingId': bookingId,
              'reservations': reservations,
            },
            SetOptions(merge: true),
          );
        }
      });
    } on BookingServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw BookingServiceException(_firebaseErrorMessage(error.code));
    } on TypeError {
      throw const BookingServiceException(
        'بيانات الحجز أو قفل المواعيد غير متوافقة.',
      );
    }
  }

  Future<void> rescheduleBooking({
    required String bookingId,
    required String ownerId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    if (_auth.currentUser?.uid != ownerId) {
      throw const BookingServiceException(
        'سجّل الدخول بحساب صاحب الملعب لإعادة جدولة الحجز.',
      );
    }
    if (!startAt.isAfter(DateTime.now()) || !endAt.isAfter(startAt)) {
      throw const BookingServiceException('الفترة الجديدة غير صالحة.');
    }

    try {
      await _functions.httpsCallable('rescheduleBookingCallable').call({
        'bookingId': bookingId,
        'startAt': startAt.toUtc().toIso8601String(),
        'endAt': endAt.toUtc().toIso8601String(),
      });
    } on FirebaseFunctionsException catch (error) {
      throw BookingServiceException(_callableErrorMessage(error));
    }
  }

  Future<String> addFieldMaintenance({
    required String fieldId,
    required DateTime startAt,
    required DateTime endAt,
    required String reason,
  }) async {
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null) {
      throw const BookingServiceException('سجّل الدخول أولاً.');
    }
    if (!startAt.isAfter(DateTime.now()) ||
        !endAt.isAfter(startAt) ||
        reason.trim().isEmpty ||
        reason.trim().length > 160) {
      throw const BookingServiceException('تحقق من بيانات فترة الصيانة.');
    }
    final maintenanceId =
        _firestore.collection('field_maintenance').doc().id;
    try {
      await _functions.httpsCallable('manageFieldMaintenance').call({
        'action': 'add',
        'fieldId': fieldId,
        'maintenanceId': maintenanceId,
        'startAt': startAt.toUtc().toIso8601String(),
        'endAt': endAt.toUtc().toIso8601String(),
        'reason': reason.trim(),
      });
      return maintenanceId;
    } on FirebaseFunctionsException catch (error) {
      throw BookingServiceException(_callableErrorMessage(error));
    }
  }

  Future<void> removeFieldMaintenance({
    required String fieldId,
    required String maintenanceId,
  }) async {
    if (_auth.currentUser == null) {
      throw const BookingServiceException('سجّل الدخول أولاً.');
    }
    try {
      await _functions.httpsCallable('manageFieldMaintenance').call({
        'action': 'remove',
        'fieldId': fieldId,
        'maintenanceId': maintenanceId,
      });
    } on FirebaseFunctionsException catch (error) {
      throw BookingServiceException(_callableErrorMessage(error));
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchFieldMaintenance(
    String ownerId,
  ) {
    return _firestore
        .collection('field_maintenance')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots();
  }

  String _callableErrorMessage(FirebaseFunctionsException error) {
    final message = error.message;
    if (message != null && message.trim().isNotEmpty) return message;
    return switch (error.code) {
      'unauthenticated' => 'انتهت جلسة الدخول. أعد تسجيل الدخول.',
      'permission-denied' => 'ليست لديك صلاحية تنفيذ هذا الإجراء.',
      'not-found' => 'لم يُعثر على الحجز أو فترة الصيانة المطلوبة.',
      'invalid-argument' => 'البيانات المرسلة غير صالحة.',
      'already-exists' => 'هذا الموعد يتعارض مع حجز أو فترة صيانة.',
      'failed-precondition' => 'لا يمكن تنفيذ الإجراء بالحالة الحالية.',
      'unavailable' => 'الخدمة غير متاحة حالياً. تحقق من اتصالك.',
      _ => 'تعذر تنفيذ الطلب. يرجى المحاولة مجدداً.',
    };
  }

  List<String> _dayKeys(DateTime startUtc, DateTime endUtc) {
    final location = _damascusLocation;
    var day = timezone.TZDateTime.from(startUtc, location);
    final finalDay = timezone.TZDateTime.from(endUtc, location);
    final keys = <String>[];

    while (true) {
      keys.add(
        '${day.year.toString().padLeft(4, '0')}'
        '${day.month.toString().padLeft(2, '0')}'
        '${day.day.toString().padLeft(2, '0')}',
      );
      final nextDay = timezone.TZDateTime(
        location,
        day.year,
        day.month,
        day.day + 1,
      );
      if (!nextDay.isBefore(finalDay) &&
          nextDay.millisecondsSinceEpoch >= endUtc.millisecondsSinceEpoch) {
        break;
      }
      if (nextDay.millisecondsSinceEpoch >= endUtc.millisecondsSinceEpoch) {
        break;
      }
      day = nextDay;
    }
    return keys;
  }

  bool _isOverlappingReservation(
    Map<String, dynamic> reservation,
    DateTime startAt,
    DateTime endAt,
  ) {
    if (reservation['status'] == 'cancelled') return false;
    return _isOverlappingDocument(reservation, startAt, endAt);
  }

  bool _isOverlappingDocument(
    Map<String, dynamic> booking,
    DateTime startAt,
    DateTime endAt,
  ) {
    final existingStart = booking['startAt'];
    final existingEnd = booking['endAt'];
    if (existingStart is! Timestamp || existingEnd is! Timestamp) {
      throw const BookingServiceException(
        'بيانات وقت الحجز الموجود غير صالحة.',
      );
    }
    return existingStart.toDate().isBefore(endAt) &&
        existingEnd.toDate().isAfter(startAt);
  }

  String _firebaseErrorMessage(String code) {
    return switch (code) {
      'permission-denied' =>
        'ليست لديك صلاحية إنشاء الحجز. تحقق من إعدادات الأمان.',
      'unavailable' => 'الخدمة غير متاحة حالياً. تحقق من اتصالك.',
      'failed-precondition' =>
        'تعذر التحقق من الحجوزات؛ قد يتطلب الأمر إنشاء فهرس Firestore.',
      'deadline-exceeded' =>
        'استغرق التحقق من الموعد وقتاً طويلاً. أعد المحاولة.',
      'aborted' =>
        'تغيرت بيانات الموعد أثناء الحجز. أعد المحاولة للتحقق من توفره.',
      _ => 'تعذر إنشاء الحجز. يرجى المحاولة مجدداً.',
    };
  }

  double _roundCurrency(double amount) => (amount * 100).round() / 100;
}
