import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../app_theme.dart';
import '../tokens.dart';
import 'app_button.dart';

/// Asks which language to switch to, and only applies the choice once it is
/// confirmed.
///
/// The confirmation step is the point of this sheet rather than an extra
/// tap for its own sake: picking the wrong row switches the entire app into
/// a script the person may not read, and on a phone that is a genuinely
/// hard thing to undo. Selecting a row here only moves the radio; nothing
/// changes until "Confirm", and "Cancel" always leaves the app exactly as
/// it was.
///
/// Every row is written in its own language ([AppLanguage.nativeName]) for
/// the same reason — someone stuck in a language they can't read still
/// recognises "العربية" or "Español".
///
/// Shared by all four apps so the four copies can't drift apart. Returns
/// the chosen language, or null if dismissed/cancelled.
Future<AppLanguage?> showLanguagePickerSheet(
  BuildContext context, {
  Future<void> Function(AppLanguage language)? onChanged,
}) async {
  final chosen = await showModalBottomSheet<AppLanguage>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _LanguagePickerSheet(
      current: AppSettings.language,
    ),
  );

  if (chosen == null) return null;
  await AppSettings.setLocale(chosen, onChanged: onChanged);
  return chosen;
}

class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet({required this.current});

  final AppLanguage current;

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  late AppLanguage _selected = widget.current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              const S(
                'Language',
                'اللغة',
                fr: 'Langue',
                es: 'Idioma',
              ).of(context),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              const S(
                'The app restarts in the language you choose.',
                'التطبيق هيشتغل باللغة اللي تختارها.',
                fr: "L'application s'affichera dans la langue choisie.",
                es: 'La aplicación se mostrará en el idioma que elijas.',
              ).of(context),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            RadioGroup<AppLanguage>(
              groupValue: _selected,
              onChanged: (value) {
                if (value != null) setState(() => _selected = value);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final language in AppLanguage.values)
                    RadioListTile<AppLanguage>(
                      value: language,
                      contentPadding: EdgeInsets.zero,
                      // The label is positioned by the sheet's own
                      // direction rather than left to the title slot, which
                      // aligns a lone word by its script: in the LTR sheet
                      // "العربية" drifted to the far right, and in the RTL
                      // sheet the three Latin names drifted to the far left,
                      // each detached from the radio it belongs to. Aligning
                      // to the directional start keeps all four rows reading
                      // as rows in every locale.
                      title: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          // Each language names itself, never translated.
                          language.nativeName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton.secondary(
                    label: const S(
                      'Cancel',
                      'إلغاء',
                      fr: 'Annuler',
                      es: 'Cancelar',
                    ).of(context),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton.primary(
                    label: const S(
                      'Confirm',
                      'تأكيد',
                      fr: 'Confirmer',
                      es: 'Confirmar',
                    ).of(context),
                    // Confirming the language already in use is a no-op the
                    // user can still tap — it simply closes the sheet.
                    onPressed: () => Navigator.pop(context, _selected),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
