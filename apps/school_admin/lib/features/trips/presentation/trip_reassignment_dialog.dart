import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../buses/data/buses_repository.dart';
import '../../common/presentation/domain_labels.dart';
import '../../drivers/data/drivers_repository.dart';
import '../../../widgets/async_error_view.dart';
import '../data/trips_repository.dart';

/// The result of the reassignment dialog — only the halves the admin
/// actually changed are populated.
class TripReassignmentDraft {
  const TripReassignmentDraft({
    this.busId,
    this.busName,
    this.busPlateNumber,
    this.driverId,
    this.driverName,
    this.reason,
  });

  final String? busId;
  final String? busName;
  final String? busPlateNumber;
  final String? driverId;
  final String? driverName;
  final String? reason;

  bool get isEmpty => busId == null && driverId == null;
}

/// Reassigns a trip's bus and/or driver at short notice.
///
/// Only offered for a trip that hasn't finished: a completed or cancelled
/// trip is refused by [TripsRepository.reassignTrip] too, but the UI never
/// gets that far — the menu item isn't shown for one. The dialog is
/// explicit that saving notifies people, because it genuinely does: the
/// deployed `onTripAssignmentChanged` function pushes to every affected
/// parent and to the newly assigned driver.
class TripReassignmentDialog extends StatefulWidget {
  const TripReassignmentDialog({
    super.key,
    required this.schoolId,
    required this.trip,
  });

  final String schoolId;
  final SchoolTrip trip;

  @override
  State<TripReassignmentDialog> createState() => _TripReassignmentDialogState();
}

class _TripReassignmentDialogState extends State<TripReassignmentDialog> {
  late String _busId = widget.trip.busId;
  late String _busName = widget.trip.busName;
  late String _busPlateNumber = widget.trip.busPlateNumber;
  late String _driverId = widget.trip.driverId;
  late String _driverName = widget.trip.driverName;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _busChanged => _busId != widget.trip.busId;
  bool get _driverChanged => _driverId != widget.trip.driverId;
  bool get _hasChanges => _busChanged || _driverChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        const S(
          'Reassign trip',
          'إعادة تخصيص الرحلة',
          fr: 'Réaffecter le trajet',
          es: 'Reasignar viaje',
        ).of(context),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.trip.routeName.isEmpty
                          ? widget.trip.routeId
                          : widget.trip.routeName,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat.yMMMd().add_jm().format(
                        widget.trip.scheduledAt,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: BusesRepository().watchBuses(widget.schoolId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const AsyncErrorView(compact: true);
                  }
                  final buses = (snapshot.data?.docs ?? const [])
                      .where((doc) => doc.data()['isActive'] == true)
                      .toList();
                  // The trip's current bus may since have been deactivated;
                  // it still has to be selectable as the current value, or
                  // the dropdown would violate its "value matches exactly
                  // one item" contract.
                  final hasCurrent = buses.any((doc) => doc.id == _busId);
                  return DropdownButtonFormField<String>(
                    initialValue: hasCurrent ? _busId : null,
                    decoration: InputDecoration(
                      labelText: const S(
                        'Bus',
                        'الأتوبيس',
                        fr: 'Bus',
                        es: 'Autobús',
                      ).of(context),
                      helperText: _busChanged
                          ? const S(
                              'Changed — parents on this route will be '
                                  'notified.',
                              'اتغيّر — أولياء الأمور على الخط ده هيتبلغوا.',
                              fr: 'Modifié — les parents sur cet itinéraire '
                                  'seront informés.',
                              es: 'Modificado — se avisará a las familias '
                                  'de esta ruta.',
                            ).of(context)
                          : null,
                    ),
                    items: [
                      for (final doc in buses)
                        DropdownMenuItem(
                          value: doc.id,
                          child: Text(
                            '${doc.data()['name'] ?? doc.id} '
                            '(${doc.data()['plateNumber'] ?? ''})',
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id == null) return;
                      final doc = buses.firstWhere((doc) => doc.id == id);
                      setState(() {
                        _busId = id;
                        _busName = doc.data()['name']?.toString() ?? '';
                        _busPlateNumber =
                            doc.data()['plateNumber']?.toString() ?? '';
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: DriversRepository().watchDrivers(
                  widget.schoolId,
                  limit: 200,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const AsyncErrorView(compact: true);
                  }
                  final drivers = (snapshot.data?.docs ?? const [])
                      .where((doc) => doc.data()['status'] == 'approved')
                      .toList();
                  final hasCurrent = drivers.any((doc) => doc.id == _driverId);
                  return DropdownButtonFormField<String>(
                    initialValue: hasCurrent ? _driverId : null,
                    decoration: InputDecoration(
                      labelText: const S(
                        'Driver',
                        'السائق',
                        fr: 'Chauffeur',
                        es: 'Conductor',
                      ).of(context),
                      helperText: _driverChanged
                          ? const S(
                              'Changed — the new driver will be notified.',
                              'اتغيّر — السائق الجديد هيتبلغ.',
                              fr: 'Modifié — le nouveau chauffeur sera '
                                  'informé.',
                              es: 'Modificado — se avisará al nuevo '
                                  'conductor.',
                            ).of(context)
                          : null,
                    ),
                    items: [
                      for (final doc in drivers)
                        DropdownMenuItem(
                          value: doc.id,
                          child: Text(
                            doc.data()['displayName']?.toString() ?? doc.id,
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id == null) return;
                      final doc = drivers.firstWhere((doc) => doc.id == id);
                      setState(() {
                        _driverId = id;
                        _driverName =
                            doc.data()['displayName']?.toString() ?? '';
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _reason,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: const S(
                    'Reason (recorded in the audit trail)',
                    'السبب (بيتسجل في سجل التدقيق)',
                    fr: "Motif (enregistré dans le journal d'audit)",
                    es: 'Motivo (registrado en el registro de auditoría)',
                  ).of(context),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        AppButton.secondary(
          label: const S(
            'Cancel',
            'إلغاء',
            fr: 'Annuler',
            es: 'Cancelar',
          ).of(context),
          onPressed: () => Navigator.pop(context),
        ),
        AppButton.primary(
          label: const S(
            'Reassign',
            'إعادة التخصيص',
            fr: 'Réaffecter',
            es: 'Reasignar',
          ).of(context),
          onPressed: _hasChanges
              ? () => Navigator.pop(
                  context,
                  TripReassignmentDraft(
                    busId: _busChanged ? _busId : null,
                    busName: _busChanged ? _busName : null,
                    busPlateNumber: _busChanged ? _busPlateNumber : null,
                    driverId: _driverChanged ? _driverId : null,
                    driverName: _driverChanged ? _driverName : null,
                    reason: _reason.text.trim().isEmpty
                        ? null
                        : _reason.text.trim(),
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

/// The recorded history of bus/driver changes on one trip, shown from the
/// trips list so an admin can see what was changed, by whom and when.
class TripReassignmentHistorySheet extends StatelessWidget {
  const TripReassignmentHistorySheet({
    super.key,
    required this.schoolId,
    required this.trip,
  });

  final String schoolId;
  final SchoolTrip trip;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SafeArea(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: TripsRepository().watchReassignments(
          schoolId: schoolId,
          tripId: trip.id,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const AsyncErrorView();
          final records = (snapshot.data?.docs ?? const [])
              .map((doc) => ReassignmentRecord.fromMap(doc.id, doc.data()))
              .toList();

          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              SectionHeader(
                title: const S(
                  'Change history',
                  'سجل التغييرات',
                  fr: 'Historique des modifications',
                  es: 'Historial de cambios',
                ).of(context),
                subtitle: trip.routeName.isEmpty ? null : trip.routeName,
              ),
              if (records.isEmpty)
                EmptyStateView(
                  compact: true,
                  icon: Icons.history,
                  title: const S(
                    'This trip has not been reassigned.',
                    'الرحلة دي متغيرتش.',
                    fr: "Ce trajet n'a pas été réaffecté.",
                    es: 'Este viaje no ha sido reasignado.',
                  ).of(context),
                )
              else
                for (final record in records)
                  ListTile(
                    leading: Icon(
                      record.type == ReassignmentType.busReassigned
                          ? Icons.directions_bus_outlined
                          : Icons.badge_outlined,
                      color: colors.info,
                    ),
                    title: Text(reassignmentTypeLabel(record.type, context)),
                    subtitle: Text(
                      [
                        DateFormat.yMMMd().add_jm().format(record.changedAt),
                        if (record.reason != null) record.reason!,
                      ].join(' · '),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
