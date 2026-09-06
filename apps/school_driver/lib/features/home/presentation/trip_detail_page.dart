import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// `hide TextDirection`: intl exports its own bidi `TextDirection` enum,
// which would otherwise collide with the `dart:ui`/Flutter one used below
// to force timestamps to render LTR inside an Arabic layout (RTL rule in
// design-system/MASTER.md §13).
import 'package:intl/intl.dart' hide TextDirection;
import 'package:school_shared/school_shared.dart';

import '../../emergencies/data/emergencies_repository.dart';
import '../../incidents/presentation/report_incident_dialog.dart';
import '../../inspections/data/inspections_repository.dart';
import '../../inspections/domain/inspection_checklist.dart';
import '../../inspections/presentation/inspection_checklist_page.dart';
import '../../schools/data/schools_repository.dart';
import '../../trips/presentation/bloc/trips_bloc.dart';
import '../../trips/presentation/stop_order_view.dart';

/// One trip's real workspace (Feature: driver app reorganization) — a full
/// screen rather than a card buried in a scrolling stack of every other
/// trip. A driver mid-route needs exactly one thing on screen: this trip,
/// its map, its next action, and its students — not that plus three other
/// cards competing for the same scroll. Reached by tapping a trip in the
/// list (`_TripCard` in driver_home_page.dart), which stays a compact
/// summary specifically so this is the only place any of this detail
/// lives.
///
/// Large, plain controls throughout — no icon-only buttons, no menus for
/// anything that happens more than rarely — because this app's driver
/// audience skews toward low literacy: a button that only makes sense once
/// you've read and understood a label is a worse button here than
/// elsewhere.
class TripDetailPage extends StatelessWidget {
  const TripDetailPage({super.key, required this.schoolId, required this.trip});

  final String schoolId;
  final SchoolTrip trip;

  @override
  Widget build(BuildContext context) {
    final isEmergency = trip.status == TripStatus.emergency;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          trip.routeName.isEmpty
              ? S('Route ${trip.routeId}', 'خط سير ${trip.routeId}').of(context)
              : trip.routeName,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _TripSummaryHeader(trip: trip),
          const SizedBox(height: AppSpacing.lg),
          ..._TripActions(schoolId: schoolId, trip: trip).build(context),
          if (isEmergency) ...[
            const SizedBox(height: AppSpacing.md),
            _ActiveEmergencyBanner(schoolId: schoolId, tripId: trip.id),
          ],
          if (trip.status == TripStatus.active ||
              trip.status == TripStatus.starting ||
              trip.status == TripStatus.paused ||
              trip.status == TripStatus.emergency) ...[
            const Divider(height: AppSpacing.xl2),
            StopOrderView(
              key: ValueKey('stops-${trip.id}'),
              schoolId: schoolId,
              tripId: trip.id,
              routeId: trip.routeId,
              tripStatus: trip.status,
              direction: trip.direction,
              routePolyline: trip.routePolyline,
            ),
          ],
        ],
      ),
    );
  }
}

/// The one dot+label pattern (`StatusBadge`) is reused for every trip status,
/// so the tone here is the single source of truth for what each status
/// means at a glance. `info` covers both "starting" and "active" (en route)
/// per design-system/MASTER.md §2; `error` is deliberately never used here —
/// it's reserved for genuine failures, not normal trip states, even
/// terminal ones like `cancelled`.
StatusTone tripStatusTone(TripStatus status) => switch (status) {
  TripStatus.scheduled => StatusTone.neutral,
  TripStatus.starting => StatusTone.info,
  TripStatus.active => StatusTone.info,
  TripStatus.paused => StatusTone.warning,
  TripStatus.completed => StatusTone.success,
  TripStatus.cancelled => StatusTone.neutral,
  TripStatus.emergency => StatusTone.emergency,
};

String tripStatusLabel(TripStatus status, BuildContext context) => switch (status) {
  TripStatus.scheduled => const S('Scheduled', 'مجدولة').of(context),
  TripStatus.starting => const S('Starting', 'جاري البدء').of(context),
  TripStatus.active => const S('En route', 'في الطريق').of(context),
  TripStatus.paused => const S('Paused', 'متوقفة مؤقتاً').of(context),
  TripStatus.completed => const S('Completed', 'مكتملة').of(context),
  TripStatus.cancelled => const S('Cancelled', 'ملغاة').of(context),
  TripStatus.emergency => const S('Emergency', 'حالة طوارئ').of(context),
};

/// Route name, direction, bus and scheduled time — everything the compact
/// list card already showed, repeated here so opening the full-screen page
/// doesn't lose that context, just adds the map and actions to it.
class _TripSummaryHeader extends StatelessWidget {
  const _TripSummaryHeader({required this.trip});

  final SchoolTrip trip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StatusBadge(
              label: tripStatusLabel(trip.status, context),
              tone: tripStatusTone(trip.status),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              trip.direction == TripDirection.returnTrip
                  ? const S('← Return home', '← رجوع للمنزل').of(context)
                  : const S('→ To school', '→ للمدرسة').of(context),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Icon(Icons.directions_bus_outlined, size: 18, color: colors.textSecondary),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                '${trip.busName} (${trip.busPlateNumber})',
                style: theme.textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Icon(Icons.schedule, size: 18, color: colors.textSecondary),
            const SizedBox(width: AppSpacing.xs),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                DateFormat.yMMMd().add_jm().format(trip.scheduledAt),
                style: theme.textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One large, plain button per action — the state-appropriate forward step
/// (start/continue/resume/complete) is always the prominent
/// `AppButton.primary` and comes first; a secondary action (pause/cancel)
/// follows; emergency reporting stays visually separate from both — see
/// `_emergencyButton` — so it never competes with, or gets mistaken for,
/// the routine trip actions above it. Moved here verbatim from the old
/// inline trip card; only its container changed.
class _TripActions {
  const _TripActions({required this.schoolId, required this.trip});

  final String schoolId;
  final SchoolTrip trip;

  List<Widget> build(BuildContext context) {
    final bloc = context.read<TripsBloc>();

    Widget primary(String label, IconData icon, VoidCallback onPressed) =>
        SizedBox(
          width: double.infinity,
          child: AppButton.primary(label: label, icon: icon, onPressed: onPressed),
        );
    Widget secondary(String label, IconData icon, VoidCallback onPressed) =>
        SizedBox(
          width: double.infinity,
          child: AppButton.secondary(label: label, icon: icon, onPressed: onPressed),
        );

    switch (trip.status) {
      case TripStatus.scheduled:
        return [
          primary(
            const S('Start trip', 'ابدأ الرحلة').of(context),
            Icons.play_arrow,
            () => _startTrip(context, alreadyStarting: false),
          ),
        ];
      case TripStatus.starting:
        return [
          primary(
            const S('Continue starting', 'كمّل البدء').of(context),
            Icons.play_arrow,
            () => _startTrip(context, alreadyStarting: true),
          ),
        ];
      case TripStatus.active:
        return [
          primary(
            const S('Complete', 'إنهاء').of(context),
            Icons.check,
            () => _completeTrip(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          secondary(
            const S('Pause', 'وقف مؤقت').of(context),
            Icons.pause,
            () => bloc.add(TripPauseRequested(schoolId: schoolId, tripId: trip.id)),
          ),
          const SizedBox(height: AppSpacing.md),
          _incidentButton(context),
          const SizedBox(height: AppSpacing.sm),
          _emergencyButton(
            context,
            () => _reportEmergency(context, bloc: bloc, schoolId: schoolId, tripId: trip.id),
          ),
        ];
      case TripStatus.paused:
        return [
          primary(
            const S('Resume', 'استكمال').of(context),
            Icons.play_arrow,
            () => bloc.add(TripResumeRequested(schoolId: schoolId, tripId: trip.id)),
          ),
          const SizedBox(height: AppSpacing.sm),
          secondary(
            const S('Cancel', 'إلغاء').of(context),
            Icons.close,
            () => bloc.add(TripCancelRequested(schoolId: schoolId, tripId: trip.id)),
          ),
          const SizedBox(height: AppSpacing.md),
          _incidentButton(context),
          const SizedBox(height: AppSpacing.sm),
          _emergencyButton(
            context,
            () => _reportEmergency(context, bloc: bloc, schoolId: schoolId, tripId: trip.id),
          ),
        ];
      case TripStatus.emergency:
        return [
          primary(
            const S('Complete', 'إنهاء').of(context),
            Icons.check,
            () => _completeTrip(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          secondary(
            const S('Cancel', 'إلغاء').of(context),
            Icons.close,
            () => bloc.add(TripCancelRequested(schoolId: schoolId, tripId: trip.id)),
          ),
        ];
      case TripStatus.completed:
      case TripStatus.cancelled:
        return const [];
    }
  }

  /// "Start" no longer starts anything on its own: a trip cannot begin
  /// without a *passed* pre-trip inspection on record for it (Feature:
  /// Vehicle Pre/Post Inspection). If one already exists, this is exactly
  /// the old one-tap start; if not, the checklist opens first and the trip
  /// only starts when it comes back passed.
  Future<bool> _blockedByStartWindow(BuildContext context) async {
    final school = await SchoolsRepository().watchSchool(schoolId: schoolId).first;
    final windowMinutes = school?.tripStartWindowMinutes;
    if (windowMinutes == null) return false;

    final earliest = trip.scheduledAt.subtract(Duration(minutes: windowMinutes));
    if (!DateTime.now().isBefore(earliest)) return false;

    if (!context.mounted) return true;
    final timeFormat = DateFormat.jm();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(const S("You can't start this trip yet", 'لسه معندكش تبدأ الرحلة')
            .of(dialogContext)),
        content: Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            S(
              'Scheduled for ${timeFormat.format(trip.scheduledAt)}. '
                  'Your school allows starting from ${timeFormat.format(earliest)} '
                  'onward.',
              'مجدولة الساعة ${timeFormat.format(trip.scheduledAt)}. '
                  'مدرستك بتسمح بالبدء من الساعة ${timeFormat.format(earliest)}.',
            ).of(dialogContext),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(const S('OK', 'تمام').of(dialogContext)),
          ),
        ],
      ),
    );
    return true;
  }

  Future<void> _startTrip(BuildContext context, {required bool alreadyStarting}) async {
    if (!alreadyStarting && await _blockedByStartWindow(context)) return;
    if (!context.mounted) return;

    final bloc = context.read<TripsBloc>();

    final bool alreadyPassed;
    try {
      alreadyPassed = await InspectionsRepository().hasPassedInspection(
        schoolId: schoolId,
        tripId: trip.id,
        type: InspectionType.pre,
      );
    } catch (error) {
      if (!context.mounted) return;
      AppSnackbar.error(context, error.toString());
      return;
    }

    if (!alreadyPassed) {
      if (!context.mounted) return;
      final passed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => InspectionChecklistPage(
            schoolId: schoolId,
            tripId: trip.id,
            busId: trip.busId,
            type: InspectionType.pre,
          ),
        ),
      );
      if (passed != true) return;
    }

    bloc.add(
      TripStartRequested(
        schoolId: schoolId,
        tripId: trip.id,
        routeId: trip.routeId,
        alreadyStarting: alreadyStarting,
      ),
    );
  }

  /// Completing the trip is dispatched immediately — the post-trip check is
  /// offered afterwards and never gates it.
  Future<void> _completeTrip(BuildContext context) async {
    context.read<TripsBloc>().add(
      TripCompleteRequested(schoolId: schoolId, tripId: trip.id),
    );

    final wantsCheck = await showAppConfirmDialog(
      context,
      title: const S('Post-trip inspection', 'فحص ما بعد الرحلة').of(context),
      message: const S(
        'Record the vehicle check for the end of this trip now?',
        'تسجّل فحص المركبة لنهاية الرحلة دي دلوقتي؟',
      ).of(context),
      confirmLabel: const S('Start check', 'ابدأ الفحص').of(context),
      cancelLabel: const S('Not now', 'مش دلوقتي').of(context),
    );
    if (wantsCheck != true || !context.mounted) return;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => InspectionChecklistPage(
          schoolId: schoolId,
          tripId: trip.id,
          busId: trip.busId,
          type: InspectionType.post,
        ),
      ),
    );
  }

  Widget _incidentButton(BuildContext context) {
    final colors = context.appColors;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.info,
          side: BorderSide(color: colors.info.withValues(alpha: 0.6)),
        ),
        onPressed: () => showReportIncidentDialog(
          context,
          schoolId: schoolId,
          tripId: trip.id,
          busId: trip.busId,
          routeId: trip.routeId,
        ),
        icon: const Icon(Icons.assignment_late_outlined),
        label: Text(const S('Report incident', 'الإبلاغ عن حادثة').of(context)),
      ),
    );
  }

  Widget _emergencyButton(BuildContext context, VoidCallback onPressed) {
    final colors = context.appColors;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.emergency,
          side: BorderSide(color: colors.emergency, width: 1.6),
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.warning_amber_rounded),
        label: Text(const S('Emergency', 'طوارئ').of(context)),
      ),
    );
  }

  Future<void> _reportEmergency(
    BuildContext context, {
    required TripsBloc bloc,
    required String schoolId,
    required String tripId,
  }) async {
    final result = await showDialog<({EmergencyType type, String? note})>(
      context: context,
      builder: (_) => const _EmergencyDialog(),
    );
    if (result == null) return;

    bloc.add(
      TripEmergencyRequested(
        schoolId: schoolId,
        tripId: tripId,
        emergencyType: result.type,
        driverNote: result.note,
      ),
    );
  }
}

String _emergencyTypeLabel(EmergencyType type, BuildContext context) {
  return switch (type) {
    EmergencyType.accident => const S('Accident', 'حادث').of(context),
    EmergencyType.vehicleBreakdown =>
      const S('Vehicle breakdown', 'عطل في المركبة').of(context),
    EmergencyType.medical => const S('Medical', 'حالة طبية').of(context),
    EmergencyType.security => const S('Security', 'أمنية').of(context),
    EmergencyType.other => const S('Other', 'أخرى').of(context),
  };
}

/// Asks for the minimum the emergency record needs (type is required by the
/// model; a note is optional) before the driver's tap actually creates
/// anything.
class _EmergencyDialog extends StatefulWidget {
  const _EmergencyDialog();

  @override
  State<_EmergencyDialog> createState() => _EmergencyDialogState();
}

class _EmergencyDialogState extends State<_EmergencyDialog> {
  EmergencyType _type = EmergencyType.other;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.emergency),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              const S('Report emergency', 'الإبلاغ عن حالة طوارئ').of(context),
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
            DropdownButtonFormField<EmergencyType>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: const S('Type', 'النوع').of(context),
              ),
              items: EmergencyType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(_emergencyTypeLabel(type, context)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _note,
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
          style: FilledButton.styleFrom(backgroundColor: colors.emergency),
          onPressed: () => Navigator.pop(context, (
            type: _type,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          )),
          child: Text(const S('Report', 'إبلاغ').of(context)),
        ),
      ],
    );
  }
}

/// Shown whenever this trip is in [TripStatus.emergency] and has a
/// still-active emergency record — lets the driver mark it resolved
/// without changing the trip's own status (which stays 'emergency' until
/// the driver explicitly completes or cancels the trip).
class _ActiveEmergencyBanner extends StatelessWidget {
  const _ActiveEmergencyBanner({required this.schoolId, required this.tripId});

  final String schoolId;
  final String tripId;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: EmergenciesRepository().watchActiveEmergency(
        schoolId: schoolId,
        tripId: tripId,
      ),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) return const SizedBox.shrink();

        final emergency = SchoolEmergency.fromMap(docs.first.id, docs.first.data());

        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.emergency.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.emergency.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: colors.emergency),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _emergencyTypeLabel(emergency.type, context),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (emergency.driverNote != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        emergency.driverNote!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.success,
                  side: BorderSide(color: colors.success),
                ),
                onPressed: () => context.read<TripsBloc>().add(
                  TripEmergencyResolveRequested(
                    schoolId: schoolId,
                    tripId: tripId,
                    emergencyId: emergency.id,
                  ),
                ),
                child: Text(const S('Mark resolved', 'تم الحل').of(context)),
              ),
            ],
          ),
        );
      },
    );
  }
}
