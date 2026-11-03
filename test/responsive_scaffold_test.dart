import 'package:fattball/models/field_model.dart';
import 'package:fattball/services/review_service.dart';
import 'package:fattball/widgets/booking_ticket.dart';
import 'package:fattball/widgets/field_card.dart';
import 'package:fattball/widgets/responsive_scaffold.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppBreakpoints', () {
    test('uses the requested mobile and tablet boundaries', () {
      expect(AppBreakpoints.isMobile(599), isTrue);
      expect(AppBreakpoints.isMobile(600), isFalse);
      expect(AppBreakpoints.isDesktop(1024), isFalse);
      expect(AppBreakpoints.isDesktop(1025), isTrue);
    });

    test('chooses field grid columns by available width', () {
      expect(AppBreakpoints.gridColumns(599), 1);
      expect(AppBreakpoints.gridColumns(600), 2);
      expect(AppBreakpoints.gridColumns(1024), 2);
      expect(AppBreakpoints.gridColumns(1025), 3);
      expect(AppBreakpoints.gridColumns(1400), 4);
    });
  });

  testWidgets('shows bottom navigation on narrow screens', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('shows a compact rail on tablet-sized screens', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isFalse,
    );
  });

  testWidgets('shows an extended rail on desktop-sized screens',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isTrue,
    );
  });

  testWidgets('field card remains usable at narrow mobile width',
      (tester) async {
    var booked = false;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fieldReviewsProvider('field-1').overrideWith(
            (ref) => Stream.value(const []),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 328,
                child: FieldCard(
                  field: _field,
                  onBook: () => booked = true,
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('احجز'));
    expect(booked, isTrue);
  });

  test('ticket outline has inward side notches', () {
    final path = const StadiumTicketClipper().getClip(const Size(240, 120));

    expect(path.contains(const Offset(120, 60)), isTrue);
    expect(path.contains(const Offset(0, 60)), isFalse);
    expect(path.contains(const Offset(240, 60)), isFalse);
  });
}

final _field = FieldModel(
  fieldId: 'field-1',
  ownerId: 'owner-1',
  name: 'ملعب المدينة',
  description: 'ملعب تجريبي',
  governorate: 'دمشق',
  district: 'المزة',
  address: 'دمشق',
  geoPoint: const GeoPoint(33.5, 36.2),
  pricePerHour: 20,
  openTime: '08:00',
  closeTime: '23:00',
  images: const [],
  isActive: true,
  createdAt: DateTime(2026),
);

Widget _app() {
  return MaterialApp(
    home: ResponsiveScaffold(
      title: 'اختبار',
      destinations: const [
        ResponsiveDestination(label: 'الرئيسية', icon: Icons.home_outlined),
        ResponsiveDestination(label: 'الحجوزات', icon: Icons.event_outlined),
      ],
      selectedIndex: 0,
      onDestinationSelected: (_) {},
      body: const Center(child: Text('محتوى الاختبار')),
    ),
  );
}
