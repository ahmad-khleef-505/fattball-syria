import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/tournament_model.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class TournamentServiceException implements Exception {
  const TournamentServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TournamentService {
  TournamentService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _tournaments =>
      _firestore.collection('tournaments');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTournaments({
    String? ownerId,
  }) {
    final query = ownerId == null
        ? _tournaments
            .where('status', whereIn: ['registration', 'scheduled'])
            .orderBy('startAt')
        : _tournaments.where('ownerId', isEqualTo: ownerId);
    return query.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTeams(String tournamentId) {
    return _tournaments
        .doc(tournamentId)
        .collection('teams')
        .orderBy('teamName')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMatches(
    String tournamentId,
  ) {
    return _tournaments
        .doc(tournamentId)
        .collection('matches')
        .orderBy('scheduledAt')
        .snapshots();
  }

  Future<String> createTournament({
    required String ownerId,
    required String fieldId,
    required String fieldName,
    required String openTime,
    required String closeTime,
    required String name,
    required String description,
    required int maxTeams,
    required double entryFeeUsd,
    required String prizeDescription,
    required DateTime registrationDeadline,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    if (name.trim().isEmpty ||
        maxTeams < 2 ||
        maxTeams > 24 ||
        entryFeeUsd < 0 ||
        !registrationDeadline.isBefore(startAt) ||
        !endAt.isAfter(startAt)) {
      throw const TournamentServiceException('تحقق من بيانات البطولة وتواريخها.');
    }

    final reference = _tournaments.doc();
    final tournament = TournamentModel(
      id: reference.id,
      ownerId: ownerId,
      fieldId: fieldId,
      fieldName: fieldName,
      openTime: openTime,
      closeTime: closeTime,
      name: name.trim(),
      description: description.trim(),
      maxTeams: maxTeams,
      entryFeeUsd: entryFeeUsd,
      prizeDescription: prizeDescription.trim(),
      registrationDeadline: registrationDeadline,
      startAt: startAt,
      endAt: endAt,
      status: 'registration',
      registeredTeams: 0,
      createdAt: DateTime.now(),
    );
    await reference.set({
      ...tournament.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return reference.id;
  }

  Future<void> registerTeam({
    required TournamentModel tournament,
    required String captainUid,
    required String captainName,
    required String teamName,
    required String paymentMethod,
    String? receiptUrl,
  }) async {
    if (teamName.trim().isEmpty ||
        !['cash', 'sham_cash', 'syriatel_cash'].contains(paymentMethod) ||
        (paymentMethod != 'cash' && receiptUrl == null)) {
      throw const TournamentServiceException('أكمل اسم الفريق وإثبات الدفع.');
    }

    final tournamentRef = _tournaments.doc(tournament.id);
    final teamRef = tournamentRef.collection('teams').doc(captainUid);
    await _firestore.runTransaction((transaction) async {
      final tournamentSnapshot = await transaction.get(tournamentRef);
      if (!tournamentSnapshot.exists) {
        throw const TournamentServiceException('هذه البطولة لم تعد متاحة.');
      }
      final data = tournamentSnapshot.data()!;
      final deadline = (data['registrationDeadline'] as Timestamp).toDate();
      if (data['status'] != 'registration' ||
          !deadline.isAfter(DateTime.now())) {
        throw const TournamentServiceException('انتهى التسجيل في هذه البطولة.');
      }
      final existing = await transaction.get(teamRef);
      if (existing.exists) {
        throw const TournamentServiceException('سبق أن سجلت فريقاً في البطولة.');
      }
      final registeredTeams = data['registeredTeams'] as int? ?? 0;
      if (registeredTeams >= (data['maxTeams'] as int)) {
        throw const TournamentServiceException('اكتمل عدد الفرق في البطولة.');
      }
      transaction.set(teamRef, {
        'teamName': teamName.trim(),
        'captainUid': captainUid,
        'captainName': captainName,
        'paymentMethod': paymentMethod,
        'paymentStatus': 'pending',
        'receiptUrl': receiptUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(tournamentRef, {
        'registeredTeams': registeredTeams + 1,
      });
    });
  }

  Future<void> reviewPayment({
    required String tournamentId,
    required String teamId,
    required bool approved,
  }) {
    return _tournaments.doc(tournamentId).collection('teams').doc(teamId).update({
      'paymentStatus': approved ? 'paid' : 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<int> createRoundRobinSchedule(TournamentModel tournament) async {
    final tournamentRef = _tournaments.doc(tournament.id);
    final teamsSnapshot = await tournamentRef
        .collection('teams')
        .orderBy('teamName')
        .get();
    if (teamsSnapshot.docs.any(
      (document) => document.data()['paymentStatus'] == 'pending',
    )) {
      throw const TournamentServiceException(
        'راجِع جميع طلبات الدفع قبل إغلاق التسجيل.',
      );
    }
    final teams = teamsSnapshot.docs
        .where((document) => document.data()['paymentStatus'] == 'paid')
        .map(
          (document) => TournamentTeam.fromMap(
            document.id,
            document.data(),
          ),
        )
        .toList();
    if (teams.length < 2) {
      throw const TournamentServiceException(
        'اعتمد رسوم فريقين على الأقل قبل إنشاء الجدول.',
      );
    }
    if (teams.length > tournament.maxTeams) {
      throw const TournamentServiceException(
        'عدد الفرق المعتمدة يتجاوز الحد.',
      );
    }

    final fixtures = buildRoundRobinFixtures(teams);
    final matchSlots = buildTournamentMatchSlots(
      startAt: tournament.startAt,
      endAt: tournament.endAt,
      openTime: tournament.openTime,
      closeTime: tournament.closeTime,
    );
    if (matchSlots.length < fixtures.length) {
      throw const TournamentServiceException(
        'مدة البطولة وساعات عمل الملعب لا تكفي لجدول الدوري. '
        'مدد فترة البطولة أو قلل عدد الفرق.',
      );
    }
    return _firestore.runTransaction((transaction) async {
      final tournamentSnapshot = await transaction.get(tournamentRef);
      if (!tournamentSnapshot.exists ||
          tournamentSnapshot.data()?['status'] != 'registration') {
        throw const TournamentServiceException(
          'التسجيل مغلق أو تم إنشاء الجدول مسبقاً.',
        );
      }
      final registeredTeams =
          tournamentSnapshot.data()?['registeredTeams'] as int? ?? 0;
      if (registeredTeams != teamsSnapshot.size) {
        throw const TournamentServiceException(
          'تغيرت طلبات التسجيل للتو. أعد المحاولة لمزامنة القائمة.',
        );
      }

      for (var index = 0; index < fixtures.length; index++) {
        final fixture = fixtures[index];
        final matchRef = tournamentRef.collection('matches').doc();
        transaction.set(matchRef, {
          'round': fixture.round,
          'homeTeamId': fixture.home.id,
          'homeTeamName': fixture.home.teamName,
          'awayTeamId': fixture.away.id,
          'awayTeamName': fixture.away.teamName,
          'scheduledAt': Timestamp.fromDate(matchSlots[index]),
          'status': 'scheduled',
          'homeScore': null,
          'awayScore': null,
        });
      }
      transaction.update(tournamentRef, {
        'status': 'scheduled',
        'scheduleCreatedAt': FieldValue.serverTimestamp(),
      });
      return fixtures.length;
    });
  }

  Future<void> saveMatchResult({
    required String tournamentId,
    required TournamentMatch match,
    required int homeScore,
    required int awayScore,
  }) async {
    if (homeScore < 0 || awayScore < 0 || homeScore > 99 || awayScore > 99) {
      throw const TournamentServiceException('النتيجة المدخلة غير صالحة.');
    }
    await _tournaments
        .doc(tournamentId)
        .collection('matches')
        .doc(match.id)
        .update({
      'homeScore': homeScore,
      'awayScore': awayScore,
      'status': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class TournamentFixture {
  const TournamentFixture(this.round, this.home, this.away);

  final int round;
  final TournamentTeam home;
  final TournamentTeam away;
}

List<TournamentFixture> buildRoundRobinFixtures(
  List<TournamentTeam> registeredTeams,
) {
  if (registeredTeams.length < 2) {
    throw ArgumentError.value(registeredTeams.length, 'registeredTeams');
  }
  final teams = List<TournamentTeam?>.from(registeredTeams);
  if (teams.length.isOdd) teams.add(null);
  final fixtures = <TournamentFixture>[];
  final rounds = teams.length - 1;
  for (var round = 0; round < rounds; round++) {
    for (var pair = 0; pair < teams.length ~/ 2; pair++) {
      final home = teams[pair];
      final away = teams[teams.length - 1 - pair];
      if (home != null && away != null) {
        fixtures.add(TournamentFixture(round + 1, home, away));
      }
    }
    final pivot = teams.removeAt(0);
    final last = teams.removeLast();
    teams.insert(0, pivot);
    teams.insert(1, last);
  }
  return fixtures;
}

List<DateTime> buildTournamentMatchSlots({
  required DateTime startAt,
  required DateTime endAt,
  required String openTime,
  required String closeTime,
}) {
  timezone_data.initializeTimeZones();
  final damascus = timezone.getLocation('Asia/Damascus');
  final start = timezone.TZDateTime.from(startAt, damascus);
  final end = timezone.TZDateTime.from(endAt, damascus);
  final openingParts = _parseClock(openTime);
  final closingParts = _parseClock(closeTime);
  final slots = <DateTime>[];

  for (var day = start.day; ; day++) {
    final date = timezone.TZDateTime(
      damascus,
      start.year,
      start.month,
      day,
    );
    var opening = timezone.TZDateTime(
      damascus,
      date.year,
      date.month,
      date.day,
      openingParts.$1,
      openingParts.$2,
    );
    var closing = timezone.TZDateTime(
      damascus,
      date.year,
      date.month,
      date.day,
      closingParts.$1,
      closingParts.$2,
    );
    if (!closing.isAfter(opening)) {
      closing = closing.add(const Duration(days: 1));
    }

    var slot = opening.isBefore(start) ? start : opening;
    while (!slot.add(const Duration(hours: 1)).isAfter(closing) &&
        !slot.add(const Duration(hours: 1)).isAfter(end)) {
      slots.add(slot);
      slot = slot.add(const Duration(hours: 2));
    }
    if (date.year == end.year &&
        date.month == end.month &&
        date.day == end.day) {
      break;
    }
  }
  return slots;
}

(int, int) _parseClock(String value) {
  final parts = value.split(':');
  if (parts.length != 2) {
    throw const TournamentServiceException('ساعات عمل الملعب غير صالحة.');
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    throw const TournamentServiceException('ساعات عمل الملعب غير صالحة.');
  }
  return (hour, minute);
}
