import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../../buses/data/buses_repository.dart';
import '../../drivers/data/drivers_repository.dart';
import '../../routes/data/routes_repository.dart';

/// Id -> human name lookups for the school's buses, routes and drivers.
///
/// Incidents, deviation records and audit entries all store *ids* only
/// (unlike trips, which denormalize names onto the document so the driver
/// and parent apps can render a card without extra read access). An admin
/// reading an incident table needs "Bus 12 · Maadi Route · Ahmed Saleh",
/// not three opaque document ids — so the admin app, which already has
/// read access to all three collections, resolves them here instead of
/// each screen re-querying them.
class SchoolDirectory {
  const SchoolDirectory({
    this.busNames = const {},
    this.busPlates = const {},
    this.routeNames = const {},
    this.driverNames = const {},
  });

  final Map<String, String> busNames;
  final Map<String, String> busPlates;
  final Map<String, String> routeNames;
  final Map<String, String> driverNames;

  /// Falls back to the raw id when a name isn't known (a deleted bus, or a
  /// driver whose member record is no longer readable) — never to a blank,
  /// so a row always identifies *something*.
  String busLabel(String? busId) {
    if (busId == null || busId.isEmpty) return '—';
    final name = busNames[busId];
    final plate = busPlates[busId];
    if (name == null) return busId;
    return plate == null || plate.isEmpty ? name : '$name ($plate)';
  }

  String routeLabel(String? routeId) {
    if (routeId == null || routeId.isEmpty) return '—';
    return routeNames[routeId] ?? routeId;
  }

  String driverLabel(String? driverId) {
    if (driverId == null || driverId.isEmpty) return '—';
    return driverNames[driverId] ?? driverId;
  }
}

/// Subscribes to buses/routes/drivers once and hands the resulting
/// [SchoolDirectory] to [builder]. Renders with whatever has arrived so
/// far rather than blocking on all three — a name filling in a moment
/// later is far better than an empty screen, and every label already
/// falls back to the raw id.
class SchoolDirectoryBuilder extends StatelessWidget {
  const SchoolDirectoryBuilder({
    super.key,
    required this.schoolId,
    required this.builder,
  });

  final String schoolId;
  final Widget Function(BuildContext context, SchoolDirectory directory)
  builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: BusesRepository().watchBuses(schoolId),
      builder: (context, busesSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: RoutesRepository().watchRoutes(schoolId),
          builder: (context, routesSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: DriversRepository().watchDrivers(schoolId, limit: 200),
              builder: (context, driversSnapshot) {
                final buses = busesSnapshot.data?.docs ?? const [];
                final routes = routesSnapshot.data?.docs ?? const [];
                final drivers = driversSnapshot.data?.docs ?? const [];

                final directory = SchoolDirectory(
                  busNames: {
                    for (final doc in buses)
                      doc.id: doc.data()['name']?.toString() ?? doc.id,
                  },
                  busPlates: {
                    for (final doc in buses)
                      doc.id: doc.data()['plateNumber']?.toString() ?? '',
                  },
                  routeNames: {
                    for (final doc in routes)
                      doc.id: doc.data()['name']?.toString() ?? doc.id,
                  },
                  driverNames: {
                    for (final doc in drivers)
                      doc.id: doc.data()['displayName']?.toString() ?? doc.id,
                  },
                );

                return builder(context, directory);
              },
            );
          },
        );
      },
    );
  }
}

/// A read-only "who/what does this id refer to" row — one icon, one line —
/// shared by the incident table, the deviation history table and the audit
/// trail so the same three facts always render identically.
class DirectoryMetaLine extends StatelessWidget {
  const DirectoryMetaLine({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: colors.textMuted),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
