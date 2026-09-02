import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_admin/widgets/pending_approval_card.dart';
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
    theme: buildAppTheme(brand: AppBrand.admin, brightness: Brightness.light, locale: const Locale('en')),
    home: Scaffold(body: child),
  );
}

void main() {
  // Regression test for a real crash found during live QA: confirming a
  // PendingApprovalCard action that requires a reason used to dispose the
  // dialog's TextEditingController immediately after the confirm dialog's
  // Future resolved — but showDialog's Future completes as soon as
  // Navigator.pop runs, before the dialog's own exit transition finishes, so
  // the still-animating TextField crashed with "A TextEditingController was
  // used after being disposed" on its next rebuild. Pumping past the full
  // exit transition (pumpAndSettle) is what actually exercises that window.
  testWidgets(
    'confirming a reason-required action does not crash during the dialog\'s exit transition',
    (tester) async {
      String? capturedReason;

      await tester.pumpWidget(
        _harness(
          PendingApprovalCard(
            icon: Icons.badge,
            title: 'Security Test Driver',
            actions: [
              ApprovalAction(
                label: 'Reject',
                icon: Icons.cancel_outlined,
                destructive: true,
                requiresReason: true,
                onConfirmed: (reason) async => capturedReason = reason,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'No longer needed');
      await tester.pump();

      // Tap the FilledButton confirm action inside the dialog specifically —
      // the card's own destructive button behind it is also a FilledButton
      // labeled "Reject", so an unscoped lookup is ambiguous.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Reject'),
        ),
      );

      // This is the exact window the bug lived in: the Future returned by
      // showDialog completes on this pump, while the dialog's TextField is
      // still mounted and mid-exit-transition for several more frames.
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(capturedReason, 'No longer needed');
    },
  );
}
