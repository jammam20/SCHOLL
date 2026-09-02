import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

/// One confirmation-dialog shape for every destructive/important action,
/// replacing hand-built `AlertDialog`s that previously varied in copy and
/// button styling screen to screen. See `design-system/MASTER.md` §8.
///
/// [reasonController], when supplied, adds a single-line reason field to
/// the dialog (e.g. "why are you rejecting this?") — the caller reads
/// `reasonController.text` after this resolves `true`. Kept as a
/// caller-supplied controller rather than widening the return type to
/// `(bool, String)`, so every existing call site with no reason field
/// keeps compiling unchanged. [reasonRequired] disables the confirm button
/// until the field is non-empty; only meaningful alongside
/// [reasonController].
///
/// Returns `true` if the user confirmed, `false`/`null` otherwise.
Future<bool?> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
  TextEditingController? reasonController,
  String? reasonHint,
  bool reasonRequired = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      final colors = context.appColors;
      final cancelText =
          cancelLabel ??
          (Localizations.localeOf(context).languageCode == 'ar'
              ? 'إلغاء'
              : 'Cancel');

      if (reasonController == null) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
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
      }

      return StatefulBuilder(
        builder: (context, setState) {
          final canConfirm =
              !reasonRequired || reasonController.text.trim().isNotEmpty;
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: reasonController,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: reasonHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelText),
              ),
              FilledButton(
                style: destructive
                    ? FilledButton.styleFrom(backgroundColor: colors.error)
                    : null,
                onPressed: canConfirm
                    ? () => Navigator.of(context).pop(true)
                    : null,
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
    },
  );
}
