import 'package:flutter/material.dart';

import '../app_theme.dart';

/// One confirmation-dialog shape for every destructive/important action,
/// replacing hand-built `AlertDialog`s that previously varied in copy and
/// button styling screen to screen. See `design-system/MASTER.md` §8.
///
/// Returns `true` if the user confirmed, `false`/`null` otherwise.
Future<bool?> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      final colors = context.appColors;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              cancelLabel ??
                  (Localizations.localeOf(context).languageCode == 'ar'
                      ? 'إلغاء'
                      : 'Cancel'),
            ),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: colors.error)
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
}
