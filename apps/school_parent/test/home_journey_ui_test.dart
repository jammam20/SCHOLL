import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_parent/features/home/presentation/child_avatar.dart';
import 'package:school_parent/features/home/presentation/child_switcher.dart';
import 'package:school_parent/features/home/presentation/journey_stage_visuals.dart';
import 'package:school_parent/features/home/presentation/journey_timeline.dart';
import 'package:school_parent/features/tracking/presentation/eta_text.dart';
import 'package:school_parent/features/trips/domain/journey_stage.dart';
import 'package:school_shared/school_shared.dart';

/// The home/tracking redesign has to hold up in four combinations, not
/// one: English and Arabic (which is also LTR vs RTL), each in light and
/// dark. A widget test is the only place that can actually be checked
/// without a browser, so every rendering test below runs the full matrix
/// and fails on any layout overflow or thrown exception in any of them.
Widget _harness({
  required Locale locale,
  required Brightness brightness,
  required Widget child,
  double width = 390,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: buildAppTheme(
      brand: AppBrand.parent,
      brightness: brightness,
      locale: locale,
    ),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

const _locales = [Locale('en'), Locale('ar')];
const _brightnesses = [Brightness.light, Brightness.dark];

/// Runs [body] once per locale/brightness combination, naming each case so
/// a failure says which of the four broke.
void forEachTheme(
  String description,
  Future<void> Function(WidgetTester tester, Locale locale, Brightness b) body,
) {
  for (final locale in _locales) {
    for (final brightness in _brightnesses) {
      testWidgets(
        '$description — ${locale.languageCode}/${brightness.name}',
        (tester) async {
          await body(tester, locale, brightness);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Student _student(String id, String name) =>
    Student(id: id, schoolId: 'school-1', name: name, isActive: true);

void main() {
  group('journey stage visuals', () {
    test('every stage has a distinct, non-empty label in both languages', () {
      for (final stage in JourneyStage.values) {
        final badge = stageBadgeLabel(stage);
        final headline = stageHeadline(stage, studentName: 'Sara');
        expect(badge.en, isNotEmpty, reason: '$stage English badge');
        expect(badge.ar, isNotEmpty, reason: '$stage Arabic badge');
        expect(headline.en, isNotEmpty, reason: '$stage English headline');
        expect(headline.ar, isNotEmpty, reason: '$stage Arabic headline');
        // A stage whose Arabic copy is byte-identical to its English is
        // almost always an untranslated string that slipped through.
        expect(
          badge.ar,
          isNot(equals(badge.en)),
          reason: '$stage badge looks untranslated',
        );
      }
    });

    test('a stage is live exactly when a bus is out for this child', () {
      // The "Track live" affordance and the map both hang off this, so it
      // must never claim a scheduled or finished trip is trackable.
      expect(stageIsLive(JourneyStage.noActiveTrip), isFalse);
      expect(stageIsLive(JourneyStage.scheduled), isFalse);
      expect(stageIsLive(JourneyStage.delayed), isFalse);
      expect(stageIsLive(JourneyStage.completed), isFalse);
      expect(stageIsLive(JourneyStage.cancelled), isFalse);

      expect(stageIsLive(JourneyStage.started), isTrue);
      expect(stageIsLive(JourneyStage.onTheWay), isTrue);
      expect(stageIsLive(JourneyStage.boarded), isTrue);
      expect(stageIsLive(JourneyStage.paused), isTrue);
      expect(stageIsLive(JourneyStage.emergency), isTrue);
    });

    test('tone and icon agree on what kind of event a stage is', () {
      // Color alone can't carry the status (design-system MASTER §12), so
      // the two must be assigned from the same understanding of the stage.
      expect(stageTone(JourneyStage.emergency), StatusTone.emergency);
      expect(stageTone(JourneyStage.cancelled), StatusTone.error);
      expect(stageTone(JourneyStage.paused), StatusTone.warning);
      expect(stageTone(JourneyStage.boarded), StatusTone.success);
      expect(stageIcon(JourneyStage.boarded), Icons.check_circle_rounded);
      expect(stageIcon(JourneyStage.emergency), Icons.warning_amber_rounded);
    });
  });

  group('distance formatting', () {
    testWidgets('rounds coarsely and switches to km', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        _harness(
          locale: const Locale('en'),
          brightness: Brightness.light,
          child: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(formatDistanceMeters(ctx, 34), '30 m');
      expect(formatDistanceMeters(ctx, 347), '350 m');
      expect(formatDistanceMeters(ctx, 1440), '1.4 km');
      expect(formatDistanceMeters(ctx, 2000), '2 km');
    });
  });

  group('JourneyTimeline', () {
    forEachTheme('renders every stage without overflowing', (
      tester,
      locale,
      brightness,
    ) async {
      for (final stage in JourneyStage.values) {
        await tester.pumpWidget(
          _harness(
            locale: locale,
            brightness: brightness,
            child: JourneyTimeline(
              stage: stage,
              hasBoarded: stage == JourneyStage.boarded,
              stopNumber: 3,
              totalStops: 8,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: '$stage');
      }
    });

    testWidgets('annotates the child’s own stop with its real position', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          locale: const Locale('en'),
          brightness: Brightness.light,
          child: const JourneyTimeline(
            stage: JourneyStage.onTheWay,
            hasBoarded: false,
            stopNumber: 3,
            totalStops: 8,
          ),
        ),
      );

      expect(find.textContaining('Stop 3 of 8'), findsOneWidget);
    });

    testWidgets('says nothing about stop position when there is no order', (
      tester,
    ) async {
      // Before the driver computes today's order there is no honest
      // "stop N of M" to show — and inventing one is the whole thing this
      // screen must not do.
      await tester.pumpWidget(
        _harness(
          locale: const Locale('en'),
          brightness: Brightness.light,
          child: const JourneyTimeline(
            stage: JourneyStage.onTheWay,
            hasBoarded: false,
          ),
        ),
      );

      expect(find.textContaining('Stop'), findsNothing);
      expect(find.textContaining('of'), findsNothing);
    });
  });

  group('JourneyProgressRail', () {
    forEachTheme('renders every stage', (tester, locale, brightness) async {
      for (final stage in JourneyStage.values) {
        await tester.pumpWidget(
          _harness(
            locale: locale,
            brightness: brightness,
            child: JourneyProgressRail(
              stage: stage,
              hasBoarded: stage == JourneyStage.boarded,
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$stage');
      }
    });

    testWidgets('reports the real step count, not a percentage', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          locale: const Locale('en'),
          brightness: Brightness.light,
          child: const JourneyProgressRail(
            stage: JourneyStage.approachingPickup,
            hasBoarded: false,
          ),
        ),
      );

      expect(
        find.textContaining(
          'Step ${reachedStepCount(JourneyStage.approachingPickup, hasBoarded: false)} '
          'of ${mainJourneyPath.length}',
        ),
        findsOneWidget,
      );
    });
  });

  group('ChildSwitcher', () {
    forEachTheme('renders and reports selection', (
      tester,
      locale,
      brightness,
    ) async {
      String? selected = 'ignored';
      final students = [
        _student('a', 'Sara'),
        _student('b', 'Omar'),
        _student('c', 'Layla'),
      ];

      await tester.pumpWidget(
        _harness(
          locale: locale,
          brightness: brightness,
          // Wide enough that all three pills are inside the viewport —
          // the switcher scrolls horizontally, and an off-screen pill is
          // never built, so a narrow harness would only ever be testing
          // the first two.
          width: 900,
          child: ChildSwitcher(
            students: students,
            selectedStudentId: 'b',
            onSelected: (id) => selected = id,
          ),
        ),
      );

      expect(find.text('Omar'), findsOneWidget);
      await tester.tap(find.text('Layla'));
      expect(selected, 'c');
    });

    testWidgets('the "all" option counts the real number of children', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          locale: const Locale('en'),
          brightness: Brightness.light,
          child: ChildSwitcher(
            students: [_student('a', 'Sara'), _student('b', 'Omar')],
            selectedStudentId: null,
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.text('All children'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('ChildAvatar', () {
    test('gives the same child the same color every time', () {
      final first = childAvatarColor('student-42');
      expect(childAvatarColor('student-42'), first);
    });

    forEachTheme('renders with and without a status ring', (
      tester,
      locale,
      brightness,
    ) async {
      await tester.pumpWidget(
        _harness(
          locale: locale,
          brightness: brightness,
          child: Row(
            children: [
              ChildAvatar(student: _student('a', 'Sara')),
              ChildAvatar(
                student: _student('b', 'Omar'),
                ringColor: const Color(0xFF1E7A4C),
              ),
              // A child with a blank name must still render something
              // rather than crashing on `name[0]`.
              ChildAvatar(student: _student('c', '')),
            ],
          ),
        ),
      );

      expect(find.text('S'), findsOneWidget);
      expect(find.text('?'), findsOneWidget);
    });
  });
}
