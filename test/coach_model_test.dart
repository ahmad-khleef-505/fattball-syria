import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/coach_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime.utc(2026, 11, 3);

  test('round-trips coach profile and hourly fee', () {
    final coach = CoachModel.fromMap('coach-1', {
      'fieldId': 'field-1',
      'ownerId': 'owner-1',
      'name': 'مدرب الناشئين',
      'specialty': 'تدريب الفئات العمرية',
      'bio': 'خبرة في تدريب الأطفال.',
      'pricePerHour': 25,
      'isActive': true,
      'createdAt': Timestamp.fromDate(createdAt),
    });

    expect(coach.coachId, 'coach-1');
    expect(coach.pricePerHour, 25);
    expect(coach.createdAt.isAtSameMomentAs(createdAt), isTrue);
    expect(
      CoachModel.fromMap(coach.coachId, coach.toMap()).isActive,
      isTrue,
    );
  });

  test('rejects a coach with a non-positive hourly fee', () {
    expect(
      () => CoachModel.fromMap('coach-1', {
        'fieldId': 'field-1',
        'ownerId': 'owner-1',
        'name': 'مدرب',
        'specialty': 'ناشئين',
        'bio': '',
        'pricePerHour': 0,
        'isActive': true,
        'createdAt': Timestamp.fromDate(createdAt),
      }),
      throwsFormatException,
    );
  });
}
