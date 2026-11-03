import 'package:fattball/models/tournament_model.dart';
import 'package:fattball/services/tournament_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

TournamentTeam _team(String id) => TournamentTeam(
      id: id,
      teamName: 'فريق $id',
      captainUid: 'captain-$id',
      captainName: 'كابتن $id',
      paymentMethod: 'cash',
      paymentStatus: 'paid',
    );

void main() {
  test('creates one round-robin fixture for every pair of four teams', () {
    final fixtures = buildRoundRobinFixtures([
      _team('1'),
      _team('2'),
      _team('3'),
      _team('4'),
    ]);
    final pairings = fixtures
        .map((fixture) => [fixture.home.id, fixture.away.id]..sort())
        .map((pair) => pair.join('-'))
        .toSet();

    expect(fixtures, hasLength(6));
    expect(pairings, hasLength(6));
    expect(fixtures.map((fixture) => fixture.round).toSet(), {1, 2, 3});
  });

  test('supports an odd number of teams with a bye each round', () {
    final fixtures = buildRoundRobinFixtures([
      _team('1'),
      _team('2'),
      _team('3'),
    ]);

    expect(fixtures, hasLength(3));
    expect(
      fixtures.map((fixture) => [fixture.home.id, fixture.away.id]..sort()),
      hasLength(3),
    );
  });

  test('rejects schedules with fewer than two teams', () {
    expect(
      () => buildRoundRobinFixtures([_team('solo')]),
      throwsArgumentError,
    );
  });

  test('places matches within tournament dates and field opening hours', () {
    timezone_data.initializeTimeZones();
    final damascus = timezone.getLocation('Asia/Damascus');
    final slots = buildTournamentMatchSlots(
      startAt: timezone.TZDateTime(damascus, 2026, 11, 3, 17),
      endAt: timezone.TZDateTime(damascus, 2026, 11, 4, 23, 59),
      openTime: '10:00',
      closeTime: '22:00',
    );

    expect(slots, hasLength(9));
    for (final slot in slots) {
      final local = timezone.TZDateTime.from(slot, damascus);
      expect(local.hour, greaterThanOrEqualTo(10));
      expect(local.add(const Duration(hours: 1)).hour, lessThanOrEqualTo(22));
      expect(
        slot.isBefore(timezone.TZDateTime(damascus, 2026, 11, 4, 23, 59)),
        isTrue,
      );
    }
    for (var index = 1; index < slots.length; index++) {
      final previous = timezone.TZDateTime.from(slots[index - 1], damascus);
      final current = timezone.TZDateTime.from(slots[index], damascus);
      if (previous.day == current.day) {
        expect(slots[index].difference(slots[index - 1]).inHours, 2);
      }
    }
  });
}
