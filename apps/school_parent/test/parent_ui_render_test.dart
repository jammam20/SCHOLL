import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_parent/features/legal/presentation/legal_page.dart';
import 'package:school_parent/widgets/parent_ui.dart';
import 'package:school_shared/school_shared.dart';

/// The same delegates the real app installs (see `lib/app/app.dart`) —
/// without them a pumped widget in Arabic warns that the locale isn't
/// supported, which is a property of the harness rather than of the screen.
const _delegates = <LocalizationsDelegate<Object>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Render checks for the shared presentation layer the redesigned parent
/// screens are built out of.
///
/// `flutter analyze` cannot catch a widget that only fails once it is laid
/// out — a `Material` given both a `shape` and a `borderRadius`, an overflow,
/// a missing `Directionality`. These tests actually pump the pieces, in both
/// languages and both themes, so a layout assertion shows up here instead of
/// on a parent's phone.
Widget _harness(
  Widget child, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: _delegates,
    theme: buildAppTheme(
      brand: AppBrand.parent,
      brightness: brightness,
      locale: locale,
    ),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  const locales = [Locale('en'), Locale('ar')];
  const brightnesses = [Brightness.light, Brightness.dark];

  group('shared parent UI renders', () {
    for (final locale in locales) {
      for (final brightness in brightnesses) {
        final label = '${locale.languageCode}/${brightness.name}';

        testWidgets('InfoNotice in every tone — $label', (tester) async {
          await tester.pumpWidget(
            _harness(
              locale: locale,
              brightness: brightness,
              Column(
                children: [
                  for (final tone in StatusTone.values)
                    InfoNotice(
                      tone: tone,
                      title: 'Title',
                      message: 'A reasonably long explanatory sentence that '
                          'has to wrap onto more than a single line.',
                    ),
                  const InfoNotice(dense: true, message: 'Dense variant.'),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });

        testWidgets('AppListCard of SettingsTiles — $label', (tester) async {
          await tester.pumpWidget(
            _harness(
              locale: locale,
              brightness: brightness,
              AppListCard(
                children: [
                  SettingsTile(
                    icon: Icons.translate_rounded,
                    title: 'Language',
                    subtitle: 'English',
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {},
                  ),
                  SettingsTile(
                    icon: Icons.dark_mode_rounded,
                    title: 'Dark mode',
                    subtitle: 'A supporting line that is long enough to need '
                        'wrapping on a narrow phone.',
                    trailing: Switch(value: true, onChanged: (_) {}),
                  ),
                  const SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Disabled row',
                    enabled: false,
                  ),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Language'), findsOneWidget);
        });

        testWidgets('LegalPage — $label', (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              supportedLocales: locales,
              localizationsDelegates: _delegates,
              theme: buildAppTheme(
                brand: AppBrand.parent,
                brightness: brightness,
                locale: locale,
              ),
              home: const LegalPage(),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('InitialAvatar handles an empty name', (tester) async {
      await tester.pumpWidget(
        _harness(
          const Row(
            children: [
              InitialAvatar(name: ''),
              InitialAvatar(name: 'Layla'),
              InitialAvatar(name: 'ياسمين'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // An unnamed record still gets a placeholder rather than a blank circle.
      expect(find.text('?'), findsOneWidget);
      expect(find.text('L'), findsOneWidget);
    });
  });

  group('relative date labels', () {
    testWidgets('name today, yesterday and tomorrow', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        _harness(Builder(builder: (context) {
          ctx = context;
          return const SizedBox.shrink();
        })),
      );

      final now = DateTime.now();
      expect(friendlyDay(ctx, now), 'Today');
      expect(
        friendlyDay(ctx, now.subtract(const Duration(days: 1))),
        'Yesterday',
      );
      expect(friendlyDay(ctx, now.add(const Duration(days: 1))), 'Tomorrow');

      // Anything further out falls back to a real date rather than an
      // ever-growing "in N days" string.
      final farOff = DateTime(now.year, 1, 1).subtract(
        const Duration(days: 400),
      );
      expect(friendlyDay(ctx, farOff), isNot('Today'));

      expect(isSameDay(now, now.add(const Duration(minutes: 1))), isTrue);
      expect(isSameDay(now, now.subtract(const Duration(days: 2))), isFalse);
    });

    testWidgets('translate the relative words for Arabic', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        _harness(
          locale: const Locale('ar'),
          Builder(builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          }),
        ),
      );
      expect(friendlyDay(ctx, DateTime.now()), 'النهاردة');
    });
  });
}
