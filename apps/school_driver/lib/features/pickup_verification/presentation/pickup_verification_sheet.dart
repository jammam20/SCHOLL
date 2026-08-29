import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../data/pickup_verification_repository.dart';

String pickupMethodLabel(PickupVerificationMethod method, BuildContext context) {
  return switch (method) {
    PickupVerificationMethod.driverManual =>
      const S('Visual check', 'تأكيد بالنظر').of(context),
    PickupVerificationMethod.qrCode => const S('QR code', 'رمز QR').of(context),
    PickupVerificationMethod.otp => const S('One-time code', 'رمز لمرة واحدة').of(context),
  };
}

/// Records who collected (or is collecting) a student. Opened from a
/// student's row in the trip's stop list, so it works both for an
/// about-to-be-picked-up student and for a hand-over at drop-off.
Future<void> showPickupVerificationSheet(
  BuildContext context, {
  required String schoolId,
  required String tripId,
  required Student student,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // The inset is read from the *sheet's* own context, not the caller's:
    // this sheet has several text fields, and reading the opening context
    // would capture the inset once (zero, before any keyboard) and never
    // lift the content off the keyboard when one appears.
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _PickupVerificationSheet(
        schoolId: schoolId,
        tripId: tripId,
        student: student,
      ),
    ),
  );
}

class _PickupVerificationSheet extends StatefulWidget {
  const _PickupVerificationSheet({
    required this.schoolId,
    required this.tripId,
    required this.student,
  });

  final String schoolId;
  final String tripId;
  final Student student;

  @override
  State<_PickupVerificationSheet> createState() =>
      _PickupVerificationSheetState();
}

class _PickupVerificationSheetState extends State<_PickupVerificationSheet> {
  final _repository = PickupVerificationRepository();
  final _code = TextEditingController();
  final _otherName = TextEditingController();
  final _notes = TextEditingController();

  PickupVerificationMethod _method = PickupVerificationMethod.driverManual;
  // Null means "the parent themselves / nobody from the authorized list" —
  // the sheet then falls back to the free-text name field.
  AuthorizedPickupPerson? _person;
  bool _submitting = false;

  @override
  void dispose() {
    _code.dispose();
    _otherName.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _isCodeMethod => _method != PickupVerificationMethod.driverManual;

  String? get _personName {
    if (_person != null) return _person!.name;
    final typed = _otherName.text.trim();
    return typed.isEmpty ? null : typed;
  }

  Future<void> _submit({required bool driverConfirmed}) async {
    setState(() => _submitting = true);

    final PickupVerificationStatus status;
    try {
      status = await _repository.recordVerification(
        schoolId: widget.schoolId,
        tripId: widget.tripId,
        studentId: widget.student.id,
        method: _method,
        driverConfirmed: driverConfirmed,
        authorizedPersonName: _personName,
        presentedCode: _code.text,
        notes: _notes.text,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppSnackbar.error(context, error.toString());
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    switch (status) {
      case PickupVerificationStatus.verified:
        AppSnackbar.success(
          context,
          const S('Pickup verified.', 'تم التحقق من الاستلام.').of(context),
        );
      case PickupVerificationStatus.failed:
        AppSnackbar.error(
          context,
          const S(
            'Recorded as not verified. Tell your school administrator.',
            'تم التسجيل كغير مُتحقق منه. أبلغ أدمن مدرستك.',
          ).of(context),
        );
      case PickupVerificationStatus.pending:
        AppSnackbar.info(
          context,
          const S(
            'Attempt recorded as pending — the code was saved for the school '
                'to check.',
            'تم تسجيل المحاولة كقيد المراجعة — تم حفظ الرمز لتراجعه المدرسة.',
          ).of(context),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final people = widget.student.authorizedPickupPersons;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            const S('Verify pickup', 'التحقق من الاستلام').of(context),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.student.name,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<PickupVerificationMethod>(
            showSelectedIcon: false,
            segments: PickupVerificationMethod.values
                .map(
                  (method) => ButtonSegment(
                    value: method,
                    label: Text(pickupMethodLabel(method, context)),
                  ),
                )
                .toList(),
            selected: {_method},
            onSelectionChanged: _submitting
                ? null
                : (selection) =>
                      setState(() => _method = selection.first),
          ),
          const SizedBox(height: AppSpacing.md),
          if (people.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: _person?.id,
              decoration: InputDecoration(
                labelText: const S(
                  'Authorized person',
                  'الشخص المصرح له',
                ).of(context),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(
                    const S('Someone else', 'شخص آخر').of(context),
                  ),
                ),
                ...people.map(
                  (person) => DropdownMenuItem(
                    value: person.id,
                    child: Text(
                      person.relationship == null
                          ? person.name
                          : '${person.name} · ${person.relationship}',
                    ),
                  ),
                ),
              ],
              onChanged: _submitting
                  ? null
                  : (id) => setState(() {
                      _person = id == null
                          ? null
                          : people.firstWhere((p) => p.id == id);
                    }),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_person == null) ...[
            TextField(
              controller: _otherName,
              enabled: !_submitting,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: people.isEmpty
                    ? const S(
                        'Who is collecting? (optional)',
                        'مين اللي بيستلم؟ (اختياري)',
                      ).of(context)
                    : const S(
                        "Their name (optional)",
                        'اسمه (اختياري)',
                      ).of(context),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_isCodeMethod) ...[
            TextField(
              controller: _code,
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: const S(
                  'Code they presented',
                  'الرمز اللي قدّمه',
                ).of(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: colors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      const S(
                        'This app has no parent-generated code to check '
                            'against yet, so this is saved as pending for the '
                            'school to confirm — not as verified.',
                        'التطبيق لسه مفيهوش رمز من ولي الأمر يتم المطابقة '
                            'عليه، فهيتسجل كقيد المراجعة عشان المدرسة تأكده — '
                            'مش كمُتحقق منه.',
                      ).of(context),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          TextField(
            controller: _notes,
            maxLines: 2,
            enabled: !_submitting,
            decoration: InputDecoration(
              labelText: const S(
                'Notes (optional)',
                'ملاحظات (اختياري)',
              ).of(context),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_isCodeMethod)
            SizedBox(
              width: double.infinity,
              child: AppButton.primary(
                label: const S('Record attempt', 'تسجيل المحاولة').of(context),
                icon: Icons.pending_actions_outlined,
                loading: _submitting,
                onPressed: () => _submit(driverConfirmed: false),
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              child: AppButton.primary(
                label: const S(
                  'Confirm handover',
                  'تأكيد التسليم',
                ).of(context),
                icon: Icons.verified_user_outlined,
                loading: _submitting,
                onPressed: () => _submit(driverConfirmed: true),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: AppButton.destructive(
                label: const S(
                  "Couldn't verify",
                  'تعذّر التحقق',
                ).of(context),
                icon: Icons.person_off_outlined,
                onPressed: _submitting
                    ? null
                    : () => _submit(driverConfirmed: false),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
