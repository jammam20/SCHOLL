import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:school_shared/school_shared.dart';

import '../../pickup_verification/presentation/pickup_verification_sheet.dart';
import '../../schools/data/schools_repository.dart';
import '../../students/data/students_repository.dart';
import '../../../widgets/async_error_view.dart';
import '../data/stop_order_repository.dart';
import '../data/trip_location_repository.dart';
import '../domain/live_trip_position.dart';
import '../domain/stop_progress.dart';
import 'bloc/trips_bloc.dart';
import 'bus_marker_icons.dart';
import 'stop_marker_icons.dart';

/// Today's pickup order for a trip, drawn as a real timeline (a connecting
/// line running through every stop, like a metro line) instead of a plain
/// numbered list — plus a small map of every student's pickup point, and a
/// live "next stop / distance / ETA" header above it.
///
/// This is the driver's own navigation view, so it is deliberately
/// low-interaction: progress (which stop is current, how far it is, when
/// the bus should get there) is *shown*, never something to tap for. The
/// only taps here are the ones that record a real fact — Board, Drop off,
/// a reorder, an absence report, a pickup verification — and each is a
/// single tap on a large target.
class StopOrderView extends StatefulWidget {
  const StopOrderView({
    super.key,
    required this.schoolId,
    required this.tripId,
    required this.routeId,
    required this.tripStatus,
  });

  final String schoolId;
  final String tripId;
  final String routeId;
  final TripStatus tripStatus;

  @override
  State<StopOrderView> createState() => _StopOrderViewState();
}

class _StopOrderViewState extends State<StopOrderView> {
  final _stopOrderRepository = StopOrderRepository();
  final _studentsRepository = StudentsRepository();

  // Created once rather than per build: this widget lives inside the trips
  // ListView and rebuilds on every trip snapshot, and re-subscribing four
  // Firestore listeners each time would churn them needlessly. The parent
  // keys this widget by trip id, so the streams and the trip they belong
  // to can never get out of step.
  late final Stream<List<Student>> _studentsStream = _studentsRepository
      .watchStudentsForRoute(schoolId: widget.schoolId, routeId: widget.routeId);
  late final Stream<List<String>> _orderStream = _stopOrderRepository
      .watchStopOrder(schoolId: widget.schoolId, tripId: widget.tripId);
  late final Stream<Set<String>> _boardedStream = _stopOrderRepository
      .watchBoardedStudents(schoolId: widget.schoolId, tripId: widget.tripId);
  late final Stream<Set<String>> _droppedOffStream = _stopOrderRepository
      .watchDroppedOffStudents(schoolId: widget.schoolId, tripId: widget.tripId);
  late final Stream<School?> _schoolStream = SchoolsRepository().watchSchool(
    schoolId: widget.schoolId,
  );
  late final Stream<LiveTripPosition?> _positionStream =
      TripLocationRepository().watchTripPosition(
        schoolId: widget.schoolId,
        tripId: widget.tripId,
      );

  /// Students this driver has successfully reported absent during this
  /// session. Held locally rather than read back from Firestore because a
  /// driver-reported absence lands in `absenceLog`, which firestore.rules
  /// makes admin-readable only — see StudentsRepository.reportAbsence. Each
  /// id in here corresponds to a write that actually committed.
  final _absenceReported = <String>{};

  Future<void> _reportAbsence(Student student) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: const S('Mark absent today', 'تسجيل غياب اليوم').of(context),
      message: S(
        'Report to the school that ${student.name} was not at their stop '
            'today? This is sent as an absence report — it does not change '
            "the student's own record, which only a parent or the school "
            'can set.',
        'تبلغ المدرسة إن ${student.name} مكانش في محطته النهاردة؟ ده بيتبعت '
            'كبلاغ غياب — مش بيغيّر سجل الطالب نفسه، ده ولي الأمر أو '
            'المدرسة بس اللي بيقدروا يعملوه.',
      ).of(context),
      confirmLabel: const S('Report absence', 'إبلاغ بالغياب').of(context),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _studentsRepository.reportAbsence(
        schoolId: widget.schoolId,
        studentId: student.id,
        studentName: student.name,
      );
    } catch (error) {
      if (!mounted) return;
      AppSnackbar.error(context, error.toString());
      return;
    }

    if (!mounted) return;
    setState(() => _absenceReported.add(student.id));
    AppSnackbar.success(
      context,
      const S(
        'Absence reported to your school.',
        'تم إبلاغ مدرستك بالغياب.',
      ).of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Student>>(
      stream: _studentsStream,
      builder: (context, studentsSnapshot) {
        if (studentsSnapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: AsyncErrorView(compact: true),
          );
        }

        final students = {
          for (final student in studentsSnapshot.data ?? const <Student>[])
            student.id: student,
        };

        return StreamBuilder<List<String>>(
          stream: _orderStream,
          builder: (context, orderSnapshot) {
            if (orderSnapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: AsyncErrorView(compact: true),
              );
            }

            final order = orderSnapshot.data ?? const <String>[];
            if (order.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: EmptyStateView(
                  compact: true,
                  icon: Icons.hourglass_top_rounded,
                  title: const S(
                    "Computing today's pickup order…",
                    'جارٍ حساب ترتيب الالتقاط لهذا اليوم…',
                  ).of(context),
                ),
              );
            }

            return StreamBuilder<Set<String>>(
              stream: _boardedStream,
              builder: (context, boardedSnapshot) {
                if (boardedSnapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: AsyncErrorView(compact: true),
                  );
                }

                final boarded = boardedSnapshot.data ?? const <String>{};

                return StreamBuilder<Set<String>>(
                  stream: _droppedOffStream,
                  builder: (context, droppedOffSnapshot) {
                    if (droppedOffSnapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: AsyncErrorView(compact: true),
                      );
                    }

                    return StreamBuilder<School?>(
                      stream: _schoolStream,
                      builder: (context, schoolSnapshot) {
                        return StreamBuilder<LiveTripPosition?>(
                          stream: _positionStream,
                          builder: (context, positionSnapshot) {
                            return _buildContent(
                              context,
                              students: students,
                              order: order,
                              boarded: boarded,
                              droppedOff:
                                  droppedOffSnapshot.data ?? const <String>{},
                              school: schoolSnapshot.data,
                              busPosition: positionSnapshot.data,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  /// The longest run of consecutive *completed* stops from the front of
  /// [order] — how far along the route the trip has actually gotten, used
  /// to split the polyline into "already covered" and "still ahead". A
  /// return trip that starts at school already has that first stop
  /// completed (see [computeStopProgress]), so the count naturally begins
  /// at 1 for it rather than 0.
  int _donePrefixLength(List<String> order, StopProgress progress) {
    var count = 0;
    for (final id in order) {
      if (!progress.completedStopIds.contains(id)) break;
      count++;
    }
    return count;
  }

  Widget _buildContent(
    BuildContext context, {
    required Map<String, Student> students,
    required List<String> order,
    required Set<String> boarded,
    required Set<String> droppedOff,
    required School? school,
    required LiveTripPosition? busPosition,
  }) {
    // The single source of truth for "where is this trip up to" — derived
    // from the same two persisted fields the rest of this screen reads, so
    // the highlighted stop can never disagree with the timeline under it.
    final progress = computeStopProgress(
      order: order,
      boardedStudents: boarded,
      schoolStopId: schoolStopId,
    );

    final ratio = MediaQuery.of(context).devicePixelRatio;

    final schoolPoint = school != null && school.hasLocation
        ? LatLng(school.latitude!, school.longitude!)
        : null;

    // The full expected path this trip is walking today, in real
    // `stopOrder` sequence — school included wherever it actually sits
    // (first, for a return trip; last, for an outbound one) — so the map
    // draws exactly the route this screen's own timeline is tracking, not
    // a decorative reordering of it.
    final routePoints = <LatLng>[];
    for (final id in order) {
      if (id == schoolStopId) {
        if (schoolPoint != null) routePoints.add(schoolPoint);
        continue;
      }
      final routeStudent = students[id];
      if (routeStudent != null && routeStudent.hasLocation) {
        routePoints.add(LatLng(routeStudent.latitude!, routeStudent.longitude!));
      }
    }

    final markers = <Marker>{};
    for (var i = 0; i < order.length; i++) {
      final id = order[i];
      final isCurrent = progress.currentStopId == id;

      if (id == schoolStopId) {
        if (schoolPoint == null) continue;
        final state = isCurrent
            ? DriverStopMarkerState.current
            : DriverStopMarkerState.school;
        final color = isCurrent
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.tertiary;
        final icon = DriverStopMarkerIcons.cached(
          number: i + 1,
          state: state,
          color: color,
          devicePixelRatio: ratio,
        );
        markers.add(
          Marker(
            markerId: const MarkerId(schoolStopId),
            position: schoolPoint,
            icon: icon ?? BitmapDescriptor.defaultMarker,
            anchor: const Offset(0.5, 0.5),
            zIndexInt: isCurrent ? 2 : 1,
            infoWindow: InfoWindow(
              title: const S('School', 'المدرسة').of(context),
            ),
          ),
        );
        continue;
      }

      final student = students[id];
      if (student == null || !student.hasLocation) continue;

      final state = droppedOff.contains(id)
          ? DriverStopMarkerState.droppedOff
          : boarded.contains(id)
          ? DriverStopMarkerState.boarded
          : isCurrent
          ? DriverStopMarkerState.current
          : DriverStopMarkerState.pending;
      final color = state == DriverStopMarkerState.droppedOff
          ? Theme.of(context).colorScheme.tertiary
          : state == DriverStopMarkerState.boarded
          ? Colors.green.shade600
          : Theme.of(context).colorScheme.primary;

      final icon = DriverStopMarkerIcons.cached(
        number: i + 1,
        state: state,
        color: color,
        devicePixelRatio: ratio,
      );
      unawaited(
        DriverStopMarkerIcons.prepare(
          number: i + 1,
          state: state,
          color: color,
          devicePixelRatio: ratio,
        ).then((_) {
          if (mounted) setState(() {});
        }),
      );

      markers.add(
        Marker(
          markerId: MarkerId(id),
          position: LatLng(student.latitude!, student.longitude!),
          icon: icon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: isCurrent ? 2 : 1,
          infoWindow: InfoWindow(title: '${i + 1}. ${student.name}'),
        ),
      );
    }

    // Prepare the school marker's icon too (it's rendered above, but the
    // `prepare` call needs to sit somewhere that doesn't skip on `continue`)
    // and the bus icon, both fire-and-forget with a repaint on completion —
    // the same cache-miss-then-repaint pattern the admin fleet map uses.
    if (schoolPoint != null) {
      final schoolIsCurrent = progress.currentStopId == schoolStopId;
      final schoolColor = schoolIsCurrent
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.tertiary;
      unawaited(
        DriverStopMarkerIcons.prepare(
          number: order.indexOf(schoolStopId) + 1,
          state: schoolIsCurrent
              ? DriverStopMarkerState.current
              : DriverStopMarkerState.school,
          color: schoolColor,
          devicePixelRatio: ratio,
        ).then((_) {
          if (mounted) setState(() {});
        }),
      );
    }

    final busColor = Theme.of(context).colorScheme.primary;
    final busIcon = DriverBusMarkerIcon.cached(
      color: busColor,
      devicePixelRatio: ratio,
    );
    unawaited(
      DriverBusMarkerIcon.prepare(
        color: busColor,
        devicePixelRatio: ratio,
      ).then((_) {
        if (mounted) setState(() {});
      }),
    );

    final busPoint = busPosition == null
        ? null
        : LatLng(busPosition.latitude, busPosition.longitude);

    // Split at how far the trip has actually gotten — same treatment as
    // the admin fleet map's per-trip polyline — so the ground already
    // covered reads differently from what's still ahead, instead of one
    // uniform line for the entire route regardless of progress.
    final polylines = <Polyline>{};
    if (routePoints.length >= 2) {
      final doneCount = _donePrefixLength(order, progress);
      if (doneCount > 0) {
        polylines.add(
          Polyline(
            polylineId: const PolylineId('route-done'),
            points: routePoints.sublist(
              0,
              (doneCount + 1).clamp(0, routePoints.length),
            ),
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 3,
            patterns: [PatternItem.dash(14), PatternItem.gap(10)],
            zIndex: 0,
          ),
        );
      }
      final remaining = routePoints.sublist(
        doneCount.clamp(0, routePoints.length),
      );
      if (remaining.length >= 2) {
        polylines.add(
          Polyline(
            polylineId: const PolylineId('route-remaining'),
            points: remaining,
            color: Theme.of(context).colorScheme.primary,
            width: 5,
            zIndex: 1,
          ),
        );
      }
    }

    final studentStops = order.where((id) => id != schoolStopId).toList();
    final boardedCount = studentStops.where(boarded.contains).length;
    final droppedOffCount = studentStops.where(droppedOff.contains).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        SectionHeader(
          title: const S("Today's route", 'مسار اليوم').of(context),
          trailing: Text(
            droppedOffCount > 0
                ? S(
                    '$boardedCount / ${studentStops.length} picked up · '
                        '$droppedOffCount dropped off',
                    '$boardedCount من ${studentStops.length} تم اصطحابهم · '
                        '$droppedOffCount تم إنزالهم',
                  ).of(context)
                : S(
                    '$boardedCount / ${studentStops.length} picked up',
                    '$boardedCount من ${studentStops.length} تم اصطحابهم',
                  ).of(context),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (markers.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 220,
              child: busPoint == null
                  ? GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: markers.first.position,
                        zoom: 12,
                      ),
                      markers: markers,
                      polylines: polylines,
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                    )
                  : TweenAnimationBuilder<LatLng>(
                      // A new `end` on every GPS tick makes the marker
                      // glide from wherever it currently sits to the new
                      // fix instead of jumping there — the same treatment
                      // the parent app's live map gives the bus it shows.
                      tween: _LatLngTween(begin: busPoint, end: busPoint),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeInOut,
                      builder: (context, animatedBus, _) => GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: animatedBus,
                          zoom: 13,
                        ),
                        markers: {
                          ...markers,
                          Marker(
                            markerId: const MarkerId('self-bus'),
                            position: animatedBus,
                            rotation: busPosition!.heading,
                            flat: true,
                            anchor: const Offset(0.5, 0.5),
                            zIndexInt: 3,
                            icon:
                                busIcon ??
                                BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueAzure,
                                ),
                            infoWindow: InfoWindow(
                              title: const S('Your bus', 'أتوبيسك').of(context),
                            ),
                          ),
                        },
                        polylines: polylines,
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                      ),
                    ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        NextStopEtaCard(
          schoolId: widget.schoolId,
          tripId: widget.tripId,
          tripStatus: widget.tripStatus,
          order: order,
          students: students,
          boarded: boarded,
        ),
        const SizedBox(height: AppSpacing.md),
        // Outbound trips end at school (the historical, still-common case);
        // a return trip starts there instead — boarding happens at school,
        // and the final stop is each student's own pickup/drop-off point.
        // Every row below needs to know which end school actually occupies:
        // the reorder dropdown's valid range depends on it (school's own
        // slot is never offered as a target), and so does its label.
        for (var i = 0; i < order.length; i++)
          _TimelineRow(
            index: i,
            total: order.length,
            isFirst: i == 0,
            isLast: i == order.length - 1,
            schoolIsFirst: order.isNotEmpty && order.first == schoolStopId,
            label: order[i] == schoolStopId
                ? (i == 0
                      ? const S(
                          'School (starting point)',
                          'المدرسة (نقطة البداية)',
                        ).of(context)
                      : const S(
                          'School (final stop)',
                          'المدرسة (آخر محطة)',
                        ).of(context))
                : students[order[i]]?.name ??
                      const S('Unknown student', 'طالب غير معروف').of(context),
            isSchool: order[i] == schoolStopId,
            isBoarded: boarded.contains(order[i]),
            isDroppedOff: droppedOff.contains(order[i]),
            isCurrent: progress.currentStopId == order[i],
            absenceReported: _absenceReported.contains(order[i]),
            isAbsentToday: students[order[i]]?.isAbsentToday ?? false,
            onMoveTo: (newIndex) {
              final updated = [...order];
              final item = updated.removeAt(i);
              updated.insert(newIndex, item);
              context.read<TripsBloc>().add(
                TripStopOrderChanged(
                  schoolId: widget.schoolId,
                  tripId: widget.tripId,
                  order: updated,
                ),
              );
            },
            onBoard: () => context.read<TripsBloc>().add(
              TripStudentBoarded(
                schoolId: widget.schoolId,
                tripId: widget.tripId,
                studentId: order[i],
              ),
            ),
            onDropOff: () => context.read<TripsBloc>().add(
              TripStudentDroppedOff(
                schoolId: widget.schoolId,
                tripId: widget.tripId,
                studentId: order[i],
              ),
            ),
            onVerifyPickup: students[order[i]] == null
                ? null
                : () => showPickupVerificationSheet(
                    context,
                    schoolId: widget.schoolId,
                    tripId: widget.tripId,
                    student: students[order[i]]!,
                  ),
            // Hidden for a student a parent (or the school) has already
            // marked absent today — reporting an absence that's already on
            // the student's own record would add a duplicate log entry and
            // tell the school nothing new.
            onMarkAbsent:
                students[order[i]] == null || students[order[i]]!.isAbsentToday
                ? null
                : () => _reportAbsence(students[order[i]]!),
          ),
      ],
    );
  }
}

/// Live "next stop, how far, how long" for the driver's own run, computed
/// with the shared [computeTripEta] engine — the same one the parent app's
/// tracking uses, fed from the same RTDB position everyone else sees, so
/// driver and parent are never looking at two different numbers.
///
/// When there's no reliable ETA this says *why* (the engine's own
/// [EtaUnavailableReason]) instead of hiding the row: "no GPS signal yet"
/// and "all stops completed" are very different situations to be in, and a
/// blank space tells the driver neither.
class NextStopEtaCard extends StatefulWidget {
  const NextStopEtaCard({
    super.key,
    required this.schoolId,
    required this.tripId,
    required this.tripStatus,
    required this.order,
    required this.students,
    required this.boarded,
  });

  final String schoolId;
  final String tripId;
  final TripStatus tripStatus;
  final List<String> order;
  final Map<String, Student> students;
  final Set<String> boarded;

  @override
  State<NextStopEtaCard> createState() => _NextStopEtaCardState();
}

class _NextStopEtaCardState extends State<NextStopEtaCard> {
  late final Stream<School?> _schoolStream = SchoolsRepository().watchSchool(
    schoolId: widget.schoolId,
  );
  late final Stream<LiveTripPosition?> _positionStream =
      TripLocationRepository().watchTripPosition(
        schoolId: widget.schoolId,
        tripId: widget.tripId,
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<School?>(
      stream: _schoolStream,
      builder: (context, schoolSnapshot) {
        return StreamBuilder<LiveTripPosition?>(
          stream: _positionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data;
            final eta = computeTripEta(
              tripStatus: widget.tripStatus,
              stopOrder: _stopPoints(schoolSnapshot.data),
              busLatitude: position?.latitude,
              busLongitude: position?.longitude,
              busSpeedMetersPerSecond: position?.speedMetersPerSecond,
              busPositionUpdatedAt: position?.updatedAt,
            );
            return _EtaPanel(
              eta: eta,
              nextStopLabel: _labelFor(eta.nextStopId, context),
            );
          },
        );
      },
    );
  }

  /// Turns the trip's stop order into the engine's point list. Stops with
  /// no usable coordinate (a student whose pickup point an admin hasn't set
  /// yet, or the school itself before its location is configured) are
  /// dropped rather than given a placeholder — the engine would otherwise
  /// measure real distances to a fictional place.
  List<TripStopPoint> _stopPoints(School? school) {
    final points = <TripStopPoint>[];
    // Same asymmetry computeStopProgress accounts for: an outbound trip
    // ends at school (only "reached" once the trip is completed), but a
    // return trip starts there (boarding happens at school, so it's
    // already behind the bus from the first stop onward).
    final schoolIsFirst =
        widget.order.isNotEmpty && widget.order.first == schoolStopId;
    for (final id in widget.order) {
      if (id == schoolStopId) {
        if (school == null || !school.hasLocation) continue;
        points.add(
          TripStopPoint(
            stopId: id,
            latitude: school.latitude!,
            longitude: school.longitude!,
            isCompleted: schoolIsFirst,
            isSchool: true,
          ),
        );
        continue;
      }
      final student = widget.students[id];
      if (student == null || !student.hasLocation) continue;
      points.add(
        TripStopPoint(
          stopId: id,
          latitude: student.latitude!,
          longitude: student.longitude!,
          isCompleted: widget.boarded.contains(id),
        ),
      );
    }
    return points;
  }

  String? _labelFor(String? stopId, BuildContext context) {
    if (stopId == null) return null;
    if (stopId == schoolStopId) {
      return const S('School', 'المدرسة').of(context);
    }
    return widget.students[stopId]?.name ??
        const S('Unknown student', 'طالب غير معروف').of(context);
  }
}

class _EtaPanel extends StatelessWidget {
  const _EtaPanel({required this.eta, required this.nextStopLabel});

  final TripEta eta;
  final String? nextStopLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final available = eta.hasEta;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: (available ? colors.info : colors.textMuted).withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: (available ? colors.info : colors.textMuted).withValues(
            alpha: 0.30,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            available ? Icons.navigation_rounded : Icons.location_off_outlined,
            size: 20,
            color: available ? colors.info : colors.textMuted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nextStopLabel == null
                      ? const S('No next stop', 'مفيش محطة تالية').of(context)
                      : S(
                          'Next stop · $nextStopLabel',
                          'المحطة التالية · $nextStopLabel',
                        ).of(context),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                if (available)
                  Text(
                    S(
                      '${formatEtaDistance(eta.distanceToNextStopMeters!, context)} '
                          'away · ${formatEtaDuration(eta.etaToNextStop!, context)}',
                      '${formatEtaDistance(eta.distanceToNextStopMeters!, context)} '
                          'من هنا · ${formatEtaDuration(eta.etaToNextStop!, context)}',
                    ).of(context),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  )
                else
                  Text(
                    S(
                      'ETA unavailable — '
                          '${etaUnavailableLabel(eta.unavailableReason, context)}',
                      'الوقت المتوقع غير متاح — '
                          '${etaUnavailableLabel(eta.unavailableReason, context)}',
                    ).of(context),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                if (available && eta.etaToFinalStop != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    S(
                      'School in ${formatEtaDuration(eta.etaToFinalStop!, context)} '
                          '· ${eta.stopsRemaining} stops left',
                      'المدرسة خلال '
                          '${formatEtaDuration(eta.etaToFinalStop!, context)} '
                          '· فاضل ${eta.stopsRemaining} محطة',
                    ).of(context),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Names the engine's own reason rather than collapsing every case into
/// "unavailable" — see [EtaUnavailableReason].
String etaUnavailableLabel(EtaUnavailableReason? reason, BuildContext context) {
  return switch (reason) {
    EtaUnavailableReason.tripNotActive =>
      const S('the trip is not running', 'الرحلة مش شغالة').of(context),
    EtaUnavailableReason.noGpsSignal =>
      const S('no GPS signal yet', 'لسه مفيش إشارة GPS').of(context),
    EtaUnavailableReason.staleGps => const S(
      'the last GPS fix is out of date',
      'آخر تحديث للموقع قديم',
    ).of(context),
    EtaUnavailableReason.allStopsCompleted =>
      const S('every stop is done', 'كل المحطات خلصت').of(context),
    EtaUnavailableReason.noRemainingStops => const S(
      'no stop on this trip has a location set',
      'مفيش محطة في الرحلة دي متسجّل ليها موقع',
    ).of(context),
    null => const S('reason unknown', 'السبب غير معروف').of(context),
  };
}

String formatEtaDistance(double meters, BuildContext context) {
  if (meters < 1000) {
    return S('${meters.round()} m', '${meters.round()} م').of(context);
  }
  return S(
    '${(meters / 1000).toStringAsFixed(1)} km',
    '${(meters / 1000).toStringAsFixed(1)} كم',
  ).of(context);
}

String formatEtaDuration(Duration duration, BuildContext context) {
  final minutes = duration.inMinutes;
  if (minutes < 1) {
    return const S('under a minute', 'أقل من دقيقة').of(context);
  }
  if (minutes < 60) {
    return S('$minutes min', '$minutes دقيقة').of(context);
  }
  final hours = duration.inHours;
  final remainder = minutes - hours * 60;
  if (remainder == 0) {
    return S('$hours h', '$hours ساعة').of(context);
  }
  return S('$hours h $remainder min', '$hours ساعة $remainder دقيقة').of(context);
}

/// One stop rendered as a segment of a vertical timeline: a dot on a
/// continuous line, the line continuing above/below to connect to
/// neighboring stops, and the stop's details to the right.
///
/// A student passes through three distinct visual states, each with its own
/// [StatusTone] so they're never told apart by position alone: pending
/// ([StatusTone.warning]), aboard the bus ([StatusTone.success]), and
/// handed over at the end of the ride ([StatusTone.info]). The stop the bus
/// is actually heading for is highlighted separately again — a tinted row
/// and an arrow, not a badge, so it reads at a glance without competing
/// with the three ridership states.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.index,
    required this.total,
    required this.isFirst,
    required this.isLast,
    required this.schoolIsFirst,
    required this.label,
    required this.isSchool,
    required this.isBoarded,
    required this.isDroppedOff,
    required this.isCurrent,
    required this.absenceReported,
    required this.isAbsentToday,
    required this.onMoveTo,
    required this.onBoard,
    required this.onDropOff,
    required this.onVerifyPickup,
    required this.onMarkAbsent,
  });

  final int index;
  final int total;
  final bool isFirst;
  final bool isLast;
  final bool schoolIsFirst;
  final String label;
  final bool isSchool;
  final bool isBoarded;
  final bool isDroppedOff;
  final bool isCurrent;
  final bool absenceReported;
  final bool isAbsentToday;
  final ValueChanged<int> onMoveTo;
  final VoidCallback onBoard;
  final VoidCallback onDropOff;
  final VoidCallback? onVerifyPickup;
  final VoidCallback? onMarkAbsent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = context.appColors;
    final dotColor = isDroppedOff
        ? appColors.info
        : isBoarded
        ? appColors.success
        : (isSchool ? colors.tertiary : colors.primary);
    final lineColor = colors.outlineVariant.withValues(alpha: 0.7);
    final isDone = isBoarded || isDroppedOff;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                SizedBox(
                  height: 6,
                  child: isFirst
                      ? null
                      : VerticalDivider(width: 2, thickness: 2, color: lineColor),
                ),
                Container(
                  width: isSchool ? 22 : 18,
                  height: isSchool ? 22 : 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? dotColor : Colors.transparent,
                    border: Border.all(color: dotColor, width: 2.5),
                  ),
                  alignment: Alignment.center,
                  child: isDroppedOff
                      ? const Icon(Icons.home_rounded, size: 11, color: Colors.white)
                      : isBoarded
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : isSchool
                      ? Icon(Icons.flag, size: 12, color: dotColor)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: dotColor,
                          ),
                        ),
                ),
                if (!isLast)
                  Expanded(
                    child: VerticalDivider(width: 2, thickness: 2, color: lineColor),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: EdgeInsets.fromLTRB(
                isCurrent ? AppSpacing.sm : 0,
                2,
                isCurrent ? AppSpacing.sm : 0,
                isCurrent ? AppSpacing.sm : 0,
              ),
              decoration: isCurrent
                  ? BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.30),
                      ),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCurrent) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.my_location_rounded,
                          size: 13,
                          color: colors.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          const S('Heading here now', 'متجه هنا دلوقتي')
                              .of(context),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontWeight: isSchool
                                ? FontWeight.w800
                                : FontWeight.w600,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            color: isDone ? colors.onSurfaceVariant : null,
                          ),
                        ),
                      ),
                      if (!isSchool && isDroppedOff)
                        StatusBadge(
                          label: const S('Dropped off', 'تم الإنزال').of(context),
                          tone: StatusTone.info,
                        )
                      else if (!isSchool && isBoarded)
                        StatusBadge(
                          label: const S('Boarded', 'تم الصعود').of(context),
                          tone: StatusTone.success,
                        ),
                    ],
                  ),
                  if (!isSchool && isBoarded && !isDroppedOff) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Spacer(),
                        _RowMenu(onVerifyPickup: onVerifyPickup),
                        const SizedBox(width: AppSpacing.sm),
                        _CompactButton(
                          label: const S('Drop off', 'إنزال').of(context),
                          onPressed: onDropOff,
                        ),
                      ],
                    ),
                  ],
                  if (!isSchool && !isBoarded) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        StatusBadge(
                          // "Absent" is the student's own record (set by a
                          // parent or the school); "Absence reported" is
                          // this driver's report of one, which deliberately
                          // does not change that record — see
                          // StudentsRepository.reportAbsence.
                          label: isAbsentToday
                              ? const S('Absent', 'غائب').of(context)
                              : absenceReported
                              ? const S(
                                  'Absence reported',
                                  'تم الإبلاغ بالغياب',
                                ).of(context)
                              : const S('Pending', 'قيد الانتظار').of(context),
                          tone: isAbsentToday || absenceReported
                              ? StatusTone.neutral
                              : StatusTone.warning,
                        ),
                        const Spacer(),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: index,
                            // Reorder targets are every index except
                            // school's own slot — school sits at index 0
                            // for a return trip (boarded there, so it's
                            // never a candidate drop-off position) or at
                            // `total - 1` for an outbound one. Previously
                            // this always excluded `total - 1` regardless
                            // of direction, so a return trip's *last*
                            // student stop — sitting at `total - 1` while
                            // school occupied index 0 — had a `value` no
                            // generated item matched, crashing
                            // DropdownButton's "exactly one item" assert.
                            items: [
                              for (var i = 0; i < total; i++)
                                if (i != (schoolIsFirst ? 0 : total - 1))
                                  DropdownMenuItem(
                                    value: i,
                                    child: Text('#${i + 1}'),
                                  ),
                            ],
                            onChanged: (newIndex) {
                              if (newIndex != null && newIndex != index) {
                                onMoveTo(newIndex);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _RowMenu(
                          onVerifyPickup: onVerifyPickup,
                          onMarkAbsent: absenceReported ? null : onMarkAbsent,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _CompactButton(
                          label: const S('Board', 'ركوب').of(context),
                          onPressed: onBoard,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactButton extends StatelessWidget {
  const _CompactButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

/// The two per-student actions that aren't part of the main flow, folded
/// behind one small menu rather than adding two more buttons to a row a
/// driver reads at a glance. Entries are omitted entirely when they don't
/// apply, so the menu never shows something that would do nothing.
class _RowMenu extends StatelessWidget {
  const _RowMenu({this.onVerifyPickup, this.onMarkAbsent});

  final VoidCallback? onVerifyPickup;
  final VoidCallback? onMarkAbsent;

  @override
  Widget build(BuildContext context) {
    if (onVerifyPickup == null && onMarkAbsent == null) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<VoidCallback>(
      tooltip: const S('More actions', 'إجراءات إضافية').of(context),
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        if (onVerifyPickup != null)
          PopupMenuItem(
            value: onVerifyPickup,
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  const S('Verify pickup', 'التحقق من الاستلام').of(context),
                ),
              ],
            ),
          ),
        if (onMarkAbsent != null)
          PopupMenuItem(
            value: onMarkAbsent,
            child: Row(
              children: [
                const Icon(Icons.person_off_outlined, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  const S('Mark absent today', 'تسجيل غياب اليوم').of(context),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Interpolates between two coordinates in a straight line — the same
/// minimal `Tween<LatLng>` the parent app's own live map uses to animate
/// its bus marker.
class _LatLngTween extends Tween<LatLng> {
  _LatLngTween({required LatLng super.begin, required LatLng super.end});

  @override
  LatLng lerp(double t) {
    final b = begin!;
    final e = end!;
    return LatLng(
      b.latitude + (e.latitude - b.latitude) * t,
      b.longitude + (e.longitude - b.longitude) * t,
    );
  }
}
