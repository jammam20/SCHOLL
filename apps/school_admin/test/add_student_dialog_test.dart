import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_shared/school_shared.dart';

const _delegates = <LocalizationsDelegate<Object>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Widget _harness(Widget child) {
  return MaterialApp(
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: _delegates,
    theme: buildAppTheme(
      brand: AppBrand.admin,
      brightness: Brightness.light,
      locale: const Locale('en'),
    ),
    home: Scaffold(body: child),
  );
}

/// Reproduces the exact dialog shape `_HomeTab._createStudent`
/// (in admin_home_page.dart) uses — three local `TextEditingController`s
/// feeding an `AlertDialog`'s `TextField`s — without needing the real
/// Firestore-backed `StudentsBloc` the production page constructs
/// internally. What's under test is the controller-disposal *timing*
/// around `showDialog`, which is exactly what crashed in production
/// ("Assertion failed: ... _dependents.isEmpty is not true") regardless of
/// what happens on confirm.
class _AddStudentButton extends StatelessWidget {
  const _AddStudentButton({required this.onConfirmed});

  final void Function(String name, String grade, String phone) onConfirmed;

  Future<void> _createStudent(BuildContext context) async {
    final name = TextEditingController();
    final grade = TextEditingController();
    final phone = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: grade, decoration: const InputDecoration(labelText: 'Grade')),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;

    if (result == true && name.text.trim().isNotEmpty) {
      onConfirmed(name.text, grade.text, phone.text);
    }

    // Deliberately not disposed here — see admin_home_page.dart's
    // _createStudent for the full explanation. This is the line that
    // regressed: reintroducing
    // `name.dispose(); grade.dispose(); phone.dispose();` right here is
    // exactly what made this test fail against the old code.
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () => _createStudent(context),
      child: const Text('Student'),
    );
  }
}

void main() {
  // Regression test for a real crash found during live QA: saving the "Add
  // student" dialog disposed its TextEditingControllers immediately after
  // the dialog's Future resolved — but showDialog's Future completes as
  // soon as Navigator.pop runs, before the dialog's own exit transition
  // finishes, so the still-animating TextFields crashed (a red error
  // screen: "Assertion failed: ... _dependents.isEmpty is not true") on
  // their next rebuild. The Firestore write itself had already succeeded
  // by the time this fired, which made it easy to miss in a quick manual
  // check — pumping past the full exit transition (pumpAndSettle) is what
  // actually exercises that window.
  testWidgets(
    "confirming Add student does not crash during the dialog's exit "
    'transition',
    (tester) async {
      String? capturedName;
      String? capturedGrade;
      String? capturedPhone;

      await tester.pumpWidget(
        _harness(
          _AddStudentButton(
            onConfirmed: (name, grade, phone) {
              capturedName = name;
              capturedGrade = grade;
              capturedPhone = phone;
            },
          ),
        ),
      );

      await tester.tap(find.text('Student'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Demo Student Three');
      await tester.enterText(find.widgetWithText(TextField, 'Grade'), 'Grade 5');
      await tester.enterText(find.widgetWithText(TextField, 'Phone'), '01000000000');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));

      // This is the exact window the bug lived in: the Future returned by
      // showDialog completes on this pump, while the dialog's TextFields
      // are still mounted and mid-exit-transition for several more frames.
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(capturedName, 'Demo Student Three');
      expect(capturedGrade, 'Grade 5');
      expect(capturedPhone, '01000000000');
    },
  );
}
