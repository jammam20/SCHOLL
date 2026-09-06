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

/// Reproduces the exact dialog shape `VehicleManagementPage._createBus` uses
/// (three local `TextEditingController`s feeding an `AlertDialog`'s
/// `TextField`s) without needing the real Firestore-backed
/// `VehiclesBloc`/`BusesBloc` the production page constructs internally —
/// this project has no Firebase test-double infrastructure, and those blocs
/// have no injection point from the page itself. What's under test is the
/// controller-disposal *timing* around `showDialog`, which is exactly what
/// crashed in production regardless of what happens on confirm.
class _AddBusButton extends StatelessWidget {
  const _AddBusButton({required this.onConfirmed});

  final void Function(String name, String plate, String capacity) onConfirmed;

  Future<void> _createBus(BuildContext context) async {
    final name = TextEditingController();
    final plate = TextEditingController();
    final capacity = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add bus'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: plate, decoration: const InputDecoration(labelText: 'Plate number')),
            TextField(controller: capacity, decoration: const InputDecoration(labelText: 'Capacity')),
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
      onConfirmed(name.text, plate.text, capacity.text);
    }

    // Deliberately not disposed here — see vehicle_management_page.dart's
    // _createBus for the full explanation. This is the line that regressed:
    // reintroducing `name.dispose(); plate.dispose(); capacity.dispose();`
    // right here is exactly what made this test fail against the old code.
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () => _createBus(context),
      child: const Text('Bus'),
    );
  }
}

void main() {
  // Regression test for a real crash found during live QA: saving the "Add
  // bus" dialog disposed its TextEditingControllers immediately after the
  // dialog's Future resolved — but showDialog's Future completes as soon as
  // Navigator.pop runs, before the dialog's own exit transition finishes, so
  // the still-animating TextFields crashed with "A TextEditingController was
  // used after being disposed" on their next rebuild. Pumping past the full
  // exit transition (pumpAndSettle) is what actually exercises that window.
  testWidgets(
    'confirming Add bus does not crash during the dialog\'s exit transition',
    (tester) async {
      String? capturedName;
      String? capturedPlate;
      String? capturedCapacity;

      await tester.pumpWidget(
        _harness(
          _AddBusButton(
            onConfirmed: (name, plate, capacity) {
              capturedName = name;
              capturedPlate = plate;
              capturedCapacity = capacity;
            },
          ),
        ),
      );

      await tester.tap(find.text('Bus'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Demo Bus 01');
      await tester.enterText(find.widgetWithText(TextField, 'Plate number'), 'TEST-0099');
      await tester.enterText(find.widgetWithText(TextField, 'Capacity'), '20');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));

      // This is the exact window the bug lived in: the Future returned by
      // showDialog completes on this pump, while the dialog's TextFields are
      // still mounted and mid-exit-transition for several more frames.
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(capturedName, 'Demo Bus 01');
      expect(capturedPlate, 'TEST-0099');
      expect(capturedCapacity, '20');
    },
  );
}
