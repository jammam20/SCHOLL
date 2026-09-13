import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../data/inspections_repository.dart';
import '../domain/inspection_checklist.dart';

String inspectionItemLabel(InspectionItem item, BuildContext context) {
  return switch (item) {
    InspectionItem.brakes => const S(
      'Brakes',
      'الفرامل',
      fr: 'Freins',
      es: 'Frenos',
    ).of(context),
    InspectionItem.tires => const S(
      'Tires',
      'الإطارات',
      fr: 'Pneus',
      es: 'Neumáticos',
    ).of(context),
    InspectionItem.lights => const S(
      'Lights',
      'الأنوار',
      fr: 'Feux',
      es: 'Luces',
    ).of(context),
    InspectionItem.mirrors => const S(
      'Mirrors',
      'المرايا',
      fr: 'Rétroviseurs',
      es: 'Espejos',
    ).of(context),
    InspectionItem.doors => const S(
      'Doors',
      'الأبواب',
      fr: 'Portes',
      es: 'Puertas',
    ).of(context),
    InspectionItem.emergencyEquipment => const S(
      'Emergency equipment',
      'معدات الطوارئ',
      fr: "Équipement d'urgence",
      es: 'Equipo de emergencia',
    ).of(context),
  };
}

/// The pre/post-trip vehicle checklist. Every item is answered with an
/// explicit OK / Not OK — there is no pre-ticked default, because a form
/// that starts out "all good" is a form a rushed driver submits without
/// reading, which is exactly the failure mode this feature exists to catch.
///
/// Pops `true` only when a submitted inspection actually passed; the trip
/// card's "Start" action treats anything else (a fail, a back-press) as
/// "don't start this trip".
class InspectionChecklistPage extends StatefulWidget {
  const InspectionChecklistPage({
    super.key,
    required this.schoolId,
    required this.tripId,
    required this.busId,
    required this.type,
  });

  final String schoolId;
  final String tripId;
  final String busId;
  final InspectionType type;

  @override
  State<InspectionChecklistPage> createState() =>
      _InspectionChecklistPageState();
}

class _InspectionChecklistPageState extends State<InspectionChecklistPage> {
  final _repository = InspectionsRepository();
  final _notes = TextEditingController();
  final _answers = <InspectionItem, bool>{};
  bool _submitting = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  bool get _allAnswered => _answers.length == InspectionItem.values.length;

  Future<void> _submit() async {
    setState(() => _submitting = true);

    final bool passed;
    try {
      passed = await _repository.submitInspection(
        schoolId: widget.schoolId,
        tripId: widget.tripId,
        busId: widget.busId,
        type: widget.type,
        items: {
          for (final entry in _answers.entries) entry.key.value: entry.value,
        },
        notes: _notes.text,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppSnackbar.error(context, error.toString());
      return;
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (passed) {
      Navigator.of(context).pop(true);
      return;
    }

    await _showBlockedDialog();
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  /// A failed inspection is recorded either way (it already committed above)
  /// — this dialog exists to make sure the driver cannot walk away from the
  /// screen believing the route is theirs to drive.
  Future<void> _showBlockedDialog() {
    final failed = failedInspectionItems({
      for (final entry in _answers.entries) entry.key.value: entry.value,
    });
    final colors = context.appColors;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.report_gmailerrorred_rounded, color: colors.emergency),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                const S(
                  '🚨 Vehicle cannot start route',
                  '🚨 المركبة لا يمكنها بدء خط السير',
                  fr: '🚨 Le véhicule ne peut pas démarrer la route',
                  es: '🚨 El vehículo no puede iniciar la ruta',
                ).of(dialogContext),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              const S(
                'A critical item failed this inspection. The trip cannot be '
                    'started. Report this to your school administrator.',
                'فشل بند حرج في هذا الفحص. لا يمكن بدء الرحلة. أبلغ أدمن '
                    'مدرستك بذلك.',
                fr: 'Un élément critique a échoué à cette inspection. Le '
                    "trajet ne peut pas démarrer. Signalez-le à "
                    "l'administrateur de votre école.",
                es: 'Un elemento crítico no pasó esta inspección. El viaje '
                    'no puede iniciar. Repórtalo al administrador de tu '
                    'escuela.',
              ).of(dialogContext),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final item in failed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(Icons.close_rounded, size: 16, color: colors.emergency),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(inspectionItemLabel(item, dialogContext)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.emergency),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              const S(
                'Understood',
                'مفهوم',
                fr: 'Compris',
                es: 'Entendido',
              ).of(dialogContext),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPre = widget.type == InspectionType.pre;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isPre
              ? const S(
                  'Pre-trip inspection',
                  'فحص ما قبل الرحلة',
                  fr: 'Inspection avant le trajet',
                  es: 'Inspección antes del viaje',
                ).of(context)
              : const S(
                  'Post-trip inspection',
                  'فحص ما بعد الرحلة',
                  fr: 'Inspection après le trajet',
                  es: 'Inspección después del viaje',
                ).of(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl2,
        ),
        children: [
          Text(
            isPre
                ? const S(
                    'Every item must pass before this trip can start.',
                    'يجب اجتياز كل بند قبل أن تبدأ هذه الرحلة.',
                    fr: 'Chaque élément doit être validé avant que ce '
                        'trajet puisse démarrer.',
                    es: 'Cada elemento debe aprobarse antes de que este '
                        'viaje pueda comenzar.',
                  ).of(context)
                : const S(
                    'Record the condition the vehicle came back in.',
                    'سجّل الحالة التي عادت بها المركبة.',
                    fr: "Enregistrez l'état dans lequel le véhicule est "
                        'revenu.',
                    es: 'Registra el estado en que regresó el vehículo.',
                  ).of(context),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final item in InspectionItem.values)
            _ChecklistRow(
              label: inspectionItemLabel(item, context),
              value: _answers[item],
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _answers[item] = value),
            ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _notes,
            maxLines: 3,
            enabled: !_submitting,
            decoration: InputDecoration(
              labelText: const S(
                'Notes (optional)',
                'ملاحظات (اختياري)',
                fr: 'Notes (facultatif)',
                es: 'Notas (opcional)',
              ).of(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: AppButton.primary(
              label: const S(
                'Submit inspection',
                'إرسال الفحص',
                fr: "Envoyer l'inspection",
                es: 'Enviar inspección',
              ).of(context),
              icon: Icons.assignment_turned_in_outlined,
              loading: _submitting,
              onPressed: _allAnswered ? _submit : null,
            ),
          ),
          if (!_allAnswered) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              const S(
                'Answer every item to submit.',
                'أجب عن كل بند حتى ترسل الفحص.',
                fr: 'Répondez à chaque élément pour envoyer.',
                es: 'Responde cada elemento para enviar.',
              ).of(context),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One item, answered with two explicit choices rather than a switch —
/// a switch has a default position, and this deliberately doesn't.
class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool? value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: true,
                label: Text(
                  const S(
                    'OK',
                    'سليم',
                    fr: 'Bon',
                    es: 'Bien',
                  ).of(context),
                ),
                icon: const Icon(Icons.check, size: 16),
              ),
              ButtonSegment(
                value: false,
                label: Text(
                  const S(
                    'Not OK',
                    'غير سليم',
                    fr: 'Mauvais',
                    es: 'Mal',
                  ).of(context),
                ),
                icon: const Icon(Icons.close, size: 16),
              ),
            ],
            selected: value == null ? const <bool>{} : {value!},
            emptySelectionAllowed: true,
            onSelectionChanged: onChanged == null
                ? null
                : (selection) {
                    if (selection.isEmpty) return;
                    onChanged!(selection.first);
                  },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (!states.contains(WidgetState.selected)) return null;
                return value == true ? colors.success : colors.emergency;
              }),
            ),
          ),
        ],
      ),
    );
  }
}
