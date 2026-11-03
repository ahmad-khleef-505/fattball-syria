import 'package:cloud_firestore/cloud_firestore.dart';

class TournamentModel {
  const TournamentModel({
    required this.id,
    required this.ownerId,
    required this.fieldId,
    required this.fieldName,
    required this.openTime,
    required this.closeTime,
    required this.name,
    required this.description,
    required this.maxTeams,
    required this.entryFeeUsd,
    required this.prizeDescription,
    required this.registrationDeadline,
    required this.startAt,
    required this.endAt,
    required this.status,
    this.registeredTeams = 0,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  final String fieldId;
  final String fieldName;
  final String openTime;
  final String closeTime;
  final String name;
  final String description;
  final int maxTeams;
  final double entryFeeUsd;
  final String prizeDescription;
  final DateTime registrationDeadline;
  final DateTime startAt;
  final DateTime endAt;
  final String status;
  final int registeredTeams;
  final DateTime createdAt;

  factory TournamentModel.fromMap(String id, Map<String, dynamic> map) {
    return TournamentModel(
      id: id,
      ownerId: map['ownerId'] as String,
      fieldId: map['fieldId'] as String,
      fieldName: map['fieldName'] as String,
      openTime: map['openTime'] as String,
      closeTime: map['closeTime'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      maxTeams: map['maxTeams'] as int,
      entryFeeUsd: (map['entryFeeUsd'] as num).toDouble(),
      prizeDescription: map['prizeDescription'] as String,
      registrationDeadline: _toDate(map['registrationDeadline']),
      startAt: _toDate(map['startAt']),
      endAt: _toDate(map['endAt']),
      status: map['status'] as String,
      registeredTeams: map['registeredTeams'] as int? ?? 0,
      createdAt: _toDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'fieldId': fieldId,
        'fieldName': fieldName,
        'openTime': openTime,
        'closeTime': closeTime,
        'name': name,
        'description': description,
        'maxTeams': maxTeams,
        'entryFeeUsd': entryFeeUsd,
        'prizeDescription': prizeDescription,
        'registrationDeadline': Timestamp.fromDate(registrationDeadline),
        'startAt': Timestamp.fromDate(startAt),
        'endAt': Timestamp.fromDate(endAt),
        'status': status,
        'registeredTeams': registeredTeams,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

class TournamentTeam {
  const TournamentTeam({
    required this.id,
    required this.teamName,
    required this.captainUid,
    required this.captainName,
    required this.paymentMethod,
    required this.paymentStatus,
    this.receiptUrl,
  });

  final String id;
  final String teamName;
  final String captainUid;
  final String captainName;
  final String paymentMethod;
  final String paymentStatus;
  final String? receiptUrl;

  factory TournamentTeam.fromMap(String id, Map<String, dynamic> map) {
    return TournamentTeam(
      id: id,
      teamName: map['teamName'] as String,
      captainUid: map['captainUid'] as String,
      captainName: map['captainName'] as String,
      paymentMethod: map['paymentMethod'] as String,
      paymentStatus: map['paymentStatus'] as String,
      receiptUrl: map['receiptUrl'] as String?,
    );
  }
}

class TournamentMatch {
  const TournamentMatch({
    required this.id,
    required this.round,
    required this.homeTeamId,
    required this.homeTeamName,
    required this.awayTeamId,
    required this.awayTeamName,
    required this.scheduledAt,
    required this.status,
    this.homeScore,
    this.awayScore,
  });

  final String id;
  final int round;
  final String homeTeamId;
  final String homeTeamName;
  final String awayTeamId;
  final String awayTeamName;
  final DateTime scheduledAt;
  final String status;
  final int? homeScore;
  final int? awayScore;

  factory TournamentMatch.fromMap(String id, Map<String, dynamic> map) {
    return TournamentMatch(
      id: id,
      round: map['round'] as int,
      homeTeamId: map['homeTeamId'] as String,
      homeTeamName: map['homeTeamName'] as String,
      awayTeamId: map['awayTeamId'] as String,
      awayTeamName: map['awayTeamName'] as String,
      scheduledAt: _toDate(map['scheduledAt']),
      status: map['status'] as String,
      homeScore: map['homeScore'] as int?,
      awayScore: map['awayScore'] as int?,
    );
  }
}

DateTime _toDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  throw const FormatException('تاريخ البطولة غير صالح.');
}
