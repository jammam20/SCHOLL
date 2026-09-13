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
import '../../trips/data/trips_repository.dart';
import '../../trips/presentation/bloc/trips_bloc.dart';
import '../../trips/presentation/stop_order_view.dart';
import '../../../tracking/domain/driver_tracking_status.dart';
import '../../../tracking/presentation/driver_tracking_banner.dart';

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
class TripDetailPage extends StatefulWidget {
  const TripDetailPage({super.key, required this.schoolId, required this.trip});

  final String schoolId;
  // The trip as it was the moment this page was opened — used as the very
  // first frame's content (and as a fallback if the live stream below
  // hasn't emitted yet) so the page never opens blank, but never read
  // again after that: see _TripDetailPageState's own doc comment.
  final SchoolTrip trip;

  @override
  State<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends State<TripDetailPage> {
  // A page reached by pushing one specific trip previously just held that
  // trip as a static, never-updated snapshot — so `routePolyline`, which
  // functions/src/index.ts writes *after* the very stop-order change that
  // opens this page, could never actually reach it: the driver had to
  // fully back out and reopen the trip to see a route the admin and
  // parent apps (which both watch a live query, not a static object) show
  // immediately. Watching the same document here instead is the fix.
  late final Stream<SchoolTrip?> _tripStream = TripsRepository().watchTrip(
    schoolId: widget.schoolId,
    tripId: widget.trip.id,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SchoolTrip?>(
      stream: _tripStream,
      initialData: widget.trip,
      builder: (context, snapshot) {
        final trip = snapshot.data ?? widget.trip;
        final schoolId = widget.schoolId;
        final isEmergency = trip.status == TripStatus.emergency;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              trip.routeName.isEmpty
                  ? S(
                      'Route ${trip.routeId}',
                      'خط سير ${trip.routeId}',
                      fr: 'Route ${trip.routeId}',
                      es: 'Ruta ${trip.routeId}',
                    ).of(context)
                  : trip.routeName,
            ),
          ),
          // Lost in the move from the old inline trip card to this
          // dedicated page: the list page's own BlocConsumer showed action
          // errors as a snackbar, but that page stays mounted *underneath*
          // this one (it's reached via Navigator.push, not a replacement),
          // so its snackbar — if it even fires while off-screen — renders
          // on a Scaffold the driver can't see. A failed "Start trip"
          // (wrong pre-trip inspection state, a denied location
          // permission, anything else `_runAction` catches) previously
          // showed nothing at all here. This is the same error-listening
          // the list page has, just scoped to whichever page is actually
          // in front of the driver.
          body: BlocListener<TripsBloc, TripsState>(
            listenWhen: (previous, current) {
              final prevTracking =
                  previous is TripsLoaded ? previous.trackingStatus : DriverTrackingStatus.stopped;
              final currTracking =
                  current is TripsLoaded ? current.trackingStatus : DriverTrackingStatus.stopped;
              final hasNewError = current is TripsLoaded && current.actionError != null;
              return hasNewError || prevTracking != currTracking;
            },
            listener: (context, state) {
              if (state is! TripsLoaded) return;
              if (state.actionError != null) {
                final code = state.actionErrorCode;
                // A null code means the failure wasn't a
                // TripOperationException (a raw Firestore or network
                // error, say) — those carry no typed identity to
                // translate, so the original text is all there is.
                AppSnackbar.error(
                  context,
                  code != null
                      ? tripOperationErrorMessage(code, context)
                      : state.actionError!,
                );
                return;
              }
              final presentation = driverTrackingStatusPresentation(state.trackingStatus, context);
              if (presentation == null) return;
              switch (presentation.tone) {
                case DriverTrackingTone.error:
                  AppSnackbar.error(context, presentation.message);
                case DriverTrackingTone.warning:
                  AppSnackbar.warning(context, presentation.message);
                case DriverTrackingTone.success:
                  AppSnackbar.success(context, presentation.message);
              }
            },
            // The map is this screen's main content once a trip is moving —
            // a driver glances at it far more than at any button — so it
            // sits right under the header, sized generously, with the
            // (rarely-tapped) actions collapsed into compact rows below it
            // rather than four full-width buttons pushing the map down and
            // small (Feature: driver app reorganization).
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _TripSummaryHeader(trip: trip),
                if (isEmergency) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ActiveEmergencyBanner(schoolId: schoolId, tripId: trip.id),
                ],
                if (trip.status == TripStatus.active ||
                    trip.status == TripStatus.starting ||
                    trip.status == TripStatus.paused ||
                    trip.status == TripStatus.emergency) ...[
                  const SizedBox(height: AppSpacing.md),
                  StopOrderView(
                    key: ValueKey('stops-${trip.id}'),
                    schoolId: schoolId,
                    tripId: trip.id,
                    routeId: trip.routeId,
                    tripStatus: trip.status,
                    direction: trip.direction,
                    routePolyline: trip.routePolyline,
                  ),
                  const Divider(height: AppSpacing.xl2),
                ] else
                  const SizedBox(height: AppSpacing.lg),
                ..._TripActions(schoolId: schoolId, trip: trip).build(context),
              ],
            ),
          ),
        );
      },
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
  TripStatus.scheduled => const S(
    'Scheduled',
    'مجدولة',
    fr: 'Prévu',
    es: 'Programado',
  ).of(context),
  TripStatus.starting => const S(
    'Starting',
    'جاري البدء',
    fr: 'Démarrage',
    es: 'Iniciando',
  ).of(context),
  TripStatus.active => const S(
    'En route',
    'في الطريق',
    fr: 'En route',
    es: 'En camino',
  ).of(context),
  TripStatus.paused => const S(
    'Paused',
    'متوقفة مؤقتاً',
    fr: 'En pause',
    es: 'Pausado',
  ).of(context),
  TripStatus.completed => const S(
    'Completed',
    'مكتملة',
    fr: 'Terminé',
    es: 'Completado',
  ).of(context),
  TripStatus.cancelled => const S(
    'Cancelled',
    'ملغاة',
    fr: 'Annulé',
    es: 'Cancelado',
  ).of(context),
  TripStatus.emergency => const S(
    'Emergency',
    'حالة طوارئ',
    fr: 'Urgence',
    es: 'Emergencia',
  ).of(context),
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
                  ? const S(
                      '← Return home',
                      '← رجوع للمنزل',
                      fr: '← Retour à la maison',
                      es: '← Regreso a casa',
                    ).of(context)
                  : const S(
                      '→ To school',
                      '→ للمدرسة',
                      fr: "→ Vers l'école",
                      es: '→ A la escuela',
                    ).of(context),
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
        AppButton.primary(label: label, icon: icon, onPressed: onPressed);
    Widget secondary(String label, IconData icon, VoidCallback onPressed) =>
        AppButton.secondary(label: label, icon: icon, onPressed: onPressed);
    Widget full(Widget button) => SizedBox(width: double.infinity, child: button);
    // Two buttons side by side rather than stacked — still full-height,
    // icon-and-label buttons (nothing shrinks below a comfortable tap
    // target), just half as tall a block, so the map above doesn't have to
    // give up its space to a wall of buttons the driver taps rarely.
    Widget row(Widget left, Widget right) => Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: right),
      ],
    );

    switch (trip.status) {
      case TripStatus.scheduled:
        return [
          full(
            primary(
              const S(
                'Start trip',
                'ابدأ الرحلة',
                fr: 'Démarrer le trajet',
                es: 'Iniciar viaje',
              ).of(context),
              Icons.play_arrow,
              () => _startTrip(context, alreadyStarting: false),
            ),
          ),
        ];
      case TripStatus.starting:
        return [
          full(
            primary(
              const S(
                'Continue starting',
                'كمّل البدء',
                fr: 'Continuer le démarrage',
                es: 'Continuar el inicio',
              ).of(context),
              Icons.play_arrow,
              () => _startTrip(context, alreadyStarting: true),
            ),
          ),
        ];
      case TripStatus.active:
        return [
          row(
            primary(
              const S(
                'Complete',
                'إنهاء',
                fr: 'Terminer',
                es: 'Completar',
              ).of(context),
              Icons.check,
              () => _completeTrip(context),
            ),
            secondary(
              const S(
                'Pause',
                'وقف مؤقت',
                fr: 'Pause',
                es: 'Pausar',
              ).of(context),
              Icons.pause,
              () => bloc.add(TripPauseRequested(schoolId: schoolId, tripId: trip.id)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          row(
            _incidentButton(context),
            _emergencyButton(
              context,
              () => _reportEmergency(context, bloc: bloc, schoolId: schoolId, tripId: trip.id),
            ),
          ),
        ];
      case TripStatus.paused:
        return [
          row(
            primary(
              const S(
                'Resume',
                'استكمال',
                fr: 'Reprendre',
                es: 'Reanudar',
              ).of(context),
              Icons.play_arrow,
              () => bloc.add(TripResumeRequested(schoolId: schoolId, tripId: trip.id)),
            ),
            secondary(
              const S(
                'Cancel',
                'إلغاء',
                fr: 'Annuler',
                es: 'Cancelar',
              ).of(context),
              Icons.close,
              () => bloc.add(TripCancelRequested(schoolId: schoolId, tripId: trip.id)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          row(
            _incidentButton(context),
            _emergencyButton(
              context,
              () => _reportEmergency(context, bloc: bloc, schoolId: schoolId, tripId: trip.id),
            ),
          ),
        ];
      case TripStatus.emergency:
        return [
          row(
            primary(
              const S(
                'Complete',
                'إنهاء',
                fr: 'Terminer',
                es: 'Completar',
              ).of(context),
              Icons.check,
              () => _completeTrip(context),
            ),
            secondary(
              const S(
                'Cancel',
                'إلغاء',
                fr: 'Annuler',
                es: 'Cancelar',
              ).of(context),
              Icons.close,
              () => bloc.add(TripCancelRequested(schoolId: schoolId, tripId: trip.id)),
            ),
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
        title: Text(
          const S(
            "You can't start this trip yet",
            'لسه معندكش تبدأ الرحلة',
            fr: 'Vous ne pouvez pas encore démarrer ce trajet',
            es: 'Aún no puedes iniciar este viaje',
          ).of(dialogContext),
        ),
        content: Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            S(
              'Scheduled for ${timeFormat.format(trip.scheduledAt)}. '
                  'Your school allows starting from ${timeFormat.format(earliest)} '
                  'onward.',
              'مجدولة الساعة ${timeFormat.format(trip.scheduledAt)}. '
                  'مدرستك بتسمح بالبدء من الساعة ${timeFormat.format(earliest)}.',
              fr: 'Prévu pour ${timeFormat.format(trip.scheduledAt)}. '
                  'Votre école autorise le démarrage à partir de '
                  '${timeFormat.format(earliest)}.',
              es: 'Programado para las '
                  '${timeFormat.format(trip.scheduledAt)}. Tu escuela '
                  'permite iniciar a partir de las '
                  '${timeFormat.format(earliest)}.',
            ).of(dialogContext),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              const S(
                'OK',
                'تمام',
                fr: 'OK',
                es: 'Aceptar',
              ).of(dialogContext),
            ),
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
      title: const S(
        'Post-trip inspection',
        'فحص ما بعد الرحلة',
        fr: 'Inspection après le trajet',
        es: 'Inspección después del viaje',
      ).of(context),
      message: const S(
        'Record the vehicle check for the end of this trip now?',
        'تسجّل فحص المركبة لنهاية الرحلة دي دلوقتي؟',
        fr: 'Enregistrer maintenant le contrôle du véhicule pour la fin '
            'de ce trajet ?',
        es: '¿Registrar ahora la revisión del vehículo para el final de '
            'este viaje?',
      ).of(context),
      confirmLabel: const S(
        'Start check',
        'ابدأ الفحص',
        fr: 'Démarrer le contrôle',
        es: 'Iniciar revisión',
      ).of(context),
      cancelLabel: const S(
        'Not now',
        'مش دلوقتي',
        fr: 'Pas maintenant',
        es: 'Ahora no',
      ).of(context),
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

  // A plain OutlinedButton with a hand-built Row rather than
  // `.icon(...)`'s own — that one lays the label out unconstrained, which
  // overflows once this button sits in a half-width Expanded slot next to
  // its sibling (see `row()` above); `Flexible` + ellipsis here matches
  // the same guard `AppButton` already carries.
  Widget _outlinedIconButton(
    BuildContext context, {
    required BorderSide side,
    required Color foregroundColor,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(foregroundColor: foregroundColor, side: side),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1)),
        ],
      ),
    );
  }

  Widget _incidentButton(BuildContext context) {
    final colors = context.appColors;
    return _outlinedIconButton(
      context,
      side: BorderSide(color: colors.info.withValues(alpha: 0.6)),
      foregroundColor: colors.info,
      icon: Icons.assignment_late_outlined,
      label: const S(
        'Report incident',
        'الإبلاغ عن حادثة',
        fr: 'Signaler un incident',
        es: 'Reportar incidente',
      ).of(context),
      onPressed: () => showReportIncidentDialog(
        context,
        schoolId: schoolId,
        tripId: trip.id,
        busId: trip.busId,
        routeId: trip.routeId,
      ),
    );
  }

  Widget _emergencyButton(BuildContext context, VoidCallback onPressed) {
    final colors = context.appColors;
    return _outlinedIconButton(
      context,
      side: BorderSide(color: colors.emergency, width: 1.6),
      foregroundColor: colors.emergency,
      icon: Icons.warning_amber_rounded,
      label: const S(
        'Emergency',
        'طوارئ',
        fr: 'Urgence',
        es: 'Emergencia',
      ).of(context),
      onPressed: onPressed,
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
    EmergencyType.accident => const S(
      'Accident',
      'حادث',
      fr: 'Accident',
      es: 'Accidente',
    ).of(context),
    EmergencyType.vehicleBreakdown => const S(
      'Vehicle breakdown',
      'عطل في المركبة',
      fr: 'Panne du véhicule',
      es: 'Avería del vehículo',
    ).of(context),
    EmergencyType.medical => const S(
      'Medical',
      'حالة طبية',
      fr: 'Médical',
      es: 'Médico',
    ).of(context),
    EmergencyType.security => const S(
      'Security',
      'أمنية',
      fr: 'Sécurité',
      es: 'Seguridad',
    ).of(context),
    EmergencyType.other => const S(
      'Other',
      'أخرى',
      fr: 'Autre',
      es: 'Otro',
    ).of(context),
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
              const S(
                'Report emergency',
                'الإبلاغ عن حالة طوارئ',
                fr: 'Signaler une urgence',
                es: 'Reportar una emergencia',
              ).of(context),
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
                labelText: const S(
                  'Type',
                  'النوع',
                  fr: 'Type',
                  es: 'Tipo',
                ).of(context),
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
                  fr: 'Notes (facultatif)',
                  es: 'Notas (opcional)',
                ).of(context),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            const S(
              'Cancel',
              'إلغاء',
              fr: 'Annuler',
              es: 'Cancelar',
            ).of(context),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colors.emergency),
          onPressed: () => Navigator.pop(context, (
            type: _type,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          )),
          child: Text(
            const S(
              'Report',
              'إبلاغ',
              fr: 'Signaler',
              es: 'Reportar',
            ).of(context),
          ),
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
                child: Text(
                  const S(
                    'Mark resolved',
                    'تم الحل',
                    fr: 'Marquer comme résolu',
                    es: 'Marcar como resuelto',
                  ).of(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
