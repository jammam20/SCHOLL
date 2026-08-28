import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:school_shared/school_shared.dart';

import '../../students/data/students_repository.dart';
import '../../../widgets/async_error_view.dart';
import '../data/stop_order_repository.dart';
import 'bloc/trips_bloc.dart';

/// Today's pickup order for a trip, drawn as a real timeline (a connecting
/// line running through every stop, like a metro line) instead of a plain
/// numbered list — plus a small map of every student's pickup point. The
/// order is computed automatically (nearest-neighbor from the driver's
/// position) when the trip starts, but the driver knows the real road
/// conditions best, so every entry except the fixed final "School" stop can
/// be moved to a different position. Tapping "Board" marks that student
/// picked up — the parent app watches the same field and updates live, no
/// push notification needed.
class StopOrderView extends StatelessWidget {
  const StopOrderView({
    super.key,
    required this.schoolId,
    required this.tripId,
    required this.routeId,
  });

  final String schoolId;
  final String tripId;
  final String routeId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Student>>(
      stream: StudentsRepository().watchStudentsForRoute(
        schoolId: schoolId,
        routeId: routeId,
      ),
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
          stream: StopOrderRepository().watchStopOrder(
            schoolId: schoolId,
            tripId: tripId,
          ),
          builder: (context, orderSnapshot) {
            if (orderSnapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: AsyncErrorView(compact: true),
              );
            }

            final order = orderSnapshot.data ?? const <String>[];
            if (order.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text("Computing today's pickup order…"),
              );
            }

            return StreamBuilder<Set<String>>(
              stream: StopOrderRepository().watchBoardedStudents(
                schoolId: schoolId,
                tripId: tripId,
              ),
              builder: (context, boardedSnapshot) {
                if (boardedSnapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: AsyncErrorView(compact: true),
                  );
                }

                final boarded = boardedSnapshot.data ?? const <String>{};

                final markers = <Marker>{};
                for (var i = 0; i < order.length; i++) {
                  final id = order[i];
                  if (id == schoolStopId) continue;
                  final student = students[id];
                  if (student == null || !student.hasLocation) continue;
                  markers.add(
                    Marker(
                      markerId: MarkerId(id),
                      position: LatLng(student.latitude!, student.longitude!),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        boarded.contains(id)
                            ? BitmapDescriptor.hueGreen
                            : BitmapDescriptor.hueOrange,
                      ),
                      infoWindow: InfoWindow(title: '${i + 1}. ${student.name}'),
                    ),
                  );
                }

                final boardedCount = order
                    .where((id) => id != schoolStopId && boarded.contains(id))
                    .length;
                final totalStudents = order
                    .where((id) => id != schoolStopId)
                    .length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          "Today's route",
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        Text(
                          '$boardedCount / $totalStudents picked up',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (markers.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 170,
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: markers.first.position,
                              zoom: 12,
                            ),
                            markers: markers,
                            zoomControlsEnabled: false,
                            myLocationButtonEnabled: false,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    for (var i = 0; i < order.length; i++)
                      _TimelineRow(
                        index: i,
                        total: order.length,
                        isFirst: i == 0,
                        isLast: i == order.length - 1,
                        label: order[i] == schoolStopId
                            ? 'School (final stop)'
                            : students[order[i]]?.name ?? 'Unknown student',
                        isSchool: order[i] == schoolStopId,
                        isBoarded: boarded.contains(order[i]),
                        onMoveTo: (newIndex) {
                          final updated = [...order];
                          final item = updated.removeAt(i);
                          updated.insert(newIndex, item);
                          context.read<TripsBloc>().add(
                            TripStopOrderChanged(
                              schoolId: schoolId,
                              tripId: tripId,
                              order: updated,
                            ),
                          );
                        },
                        onBoard: () => context.read<TripsBloc>().add(
                          TripStudentBoarded(
                            schoolId: schoolId,
                            tripId: tripId,
                            studentId: order[i],
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

/// One stop rendered as a segment of a vertical timeline: a dot on a
/// continuous line (green + filled once boarded, hollow otherwise), the
/// line continuing above/below to connect to neighboring stops, and the
/// stop's details to the right.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.index,
    required this.total,
    required this.isFirst,
    required this.isLast,
    required this.label,
    required this.isSchool,
    required this.isBoarded,
    required this.onMoveTo,
    required this.onBoard,
  });

  final int index;
  final int total;
  final bool isFirst;
  final bool isLast;
  final String label;
  final bool isSchool;
  final bool isBoarded;
  final ValueChanged<int> onMoveTo;
  final VoidCallback onBoard;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dotColor = isBoarded
        ? const Color(0xFF17B26A)
        : (isSchool ? colors.tertiary : colors.primary);
    final lineColor = colors.outlineVariant.withValues(alpha: 0.7);

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
                    color: isBoarded ? dotColor : Colors.transparent,
                    border: Border.all(color: dotColor, width: 2.5),
                  ),
                  alignment: Alignment.center,
                  child: isBoarded
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
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: isSchool ? FontWeight.w800 : FontWeight.w600,
                        decoration: isBoarded ? TextDecoration.lineThrough : null,
                        color: isBoarded ? colors.onSurfaceVariant : null,
                      ),
                    ),
                  ),
                  if (!isSchool && !isBoarded) ...[
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: index,
                        items: [
                          for (var i = 0; i < total - 1; i++)
                            DropdownMenuItem(value: i, child: Text('#${i + 1}')),
                        ],
                        onChanged: (newIndex) {
                          if (newIndex != null && newIndex != index) {
                            onMoveTo(newIndex);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onBoard,
                      child: const Text('Board'),
                    ),
                  ] else if (!isSchool && isBoarded)
                    Text(
                      'Boarded',
                      style: TextStyle(
                        color: const Color(0xFF17B26A),
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
