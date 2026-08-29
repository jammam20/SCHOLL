import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../data/incidents_repository.dart';

String incidentTypeLabel(IncidentType type, BuildContext context) {
  return switch (type) {
    IncidentType.accident => const S('Accident', 'حادث').of(context),
    IncidentType.vehicleBreakdown =>
      const S('Vehicle breakdown', 'عطل في المركبة').of(context),
    IncidentType.studentMedical =>
      const S('Student medical', 'حالة طبية لطالب').of(context),
    IncidentType.studentBehavior =>
      const S('Student behavior', 'سلوك طالب').of(context),
    IncidentType.routeBlocked =>
      const S('Route blocked', 'الطريق مغلق').of(context),
    IncidentType.policeEmergency =>
      const S('Police / authorities', 'الشرطة / الجهات المختصة').of(context),
    IncidentType.other => const S('Other', 'أخرى').of(context),
  };
}

/// Collects an incident report and files it. Unlike the emergency flow this
/// doesn't go through TripsBloc at all — filing an incident changes nothing
/// about the trip's own status (see IncidentsRepository's class doc), so
/// there's no trip state for the bloc to own here, and routing it through
/// the trip lifecycle bloc would only invite exactly the escalation this
/// feature is defined to avoid.
Future<void> showReportIncidentDialog(
  BuildContext context, {
  required String schoolId,
  required String tripId,
  required String busId,
  required String routeId,
}) async {
  final result = await showDialog<({IncidentType type, String? notes})>(
    context: context,
    builder: (_) => const _IncidentDialog(),
  );
  if (result == null || !context.mounted) return;

  try {
    await IncidentsRepository().reportIncident(
      schoolId: schoolId,
      tripId: tripId,
      busId: busId,
      routeId: routeId,
      type: result.type,
      notes: result.notes,
    );
  } catch (error) {
    if (!context.mounted) return;
    AppSnackbar.error(context, error.toString());
    return;
  }

  if (!context.mounted) return;
  AppSnackbar.success(
    context,
    const S(
      'Incident reported to your school.',
      'تم إبلاغ مدرستك بالحادثة.',
    ).of(context),
  );
}

class _IncidentDialog extends StatefulWidget {
  const _IncidentDialog();

  @override
  State<_IncidentDialog> createState() => _IncidentDialogState();
}

class _IncidentDialogState extends State<_IncidentDialog> {
  IncidentType _type = IncidentType.routeBlocked;
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.assignment_late_outlined, color: colors.info),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              const S('Report incident', 'الإبلاغ عن حادثة').of(context),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              const S(
                'For operational issues that are not an emergency. Your trip '
                    'keeps running and parents are not alerted.',
                'للمشكلات التشغيلية غير الطارئة. رحلتك تكمل عادي ومش هيتم '
                    'تنبيه أولياء الأمور.',
              ).of(context),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<IncidentType>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: const S('Type', 'النوع').of(context),
              ),
              items: IncidentType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(incidentTypeLabel(type, context)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: const S(
                  'Notes (optional)',
                  'ملاحظات (اختياري)',
                ).of(context),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(const S('Cancel', 'إلغاء').of(context)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            type: _type,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          )),
          child: Text(const S('Report', 'إبلاغ').of(context)),
        ),
      ],
    );
  }
}
