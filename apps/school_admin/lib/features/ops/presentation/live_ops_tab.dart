import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../../app/analytics.dart';
import '../../../widgets/async_error_view.dart';
import '../../emergencies/data/emergencies_repository.dart';
import '../../trips/data/trips_repository.dart';
import '../data/ops_tracking_repository.dart';

/// Every bus currently on the road, on one map — so the school can see at a
/// glance where all its trips are, not just one at a time.
class LiveOpsTab extends StatefulWidget {
  const LiveOpsTab({super.key, required this.schoolId});

  final String schoolId;

  @override
  State<LiveOpsTab> createState() => _LiveOpsTabState();
}

class _LiveOpsTabState extends State<LiveOpsTab> {
  static const _fallbackCenter = LatLng(30.0444, 31.2357);

  final Map<String, LatLng> _positions = {};

  void _updatePosition(String tripId, LatLng? position) {
    if (!mounted) return;
    setState(() {
      if (position == null) {
        _positions.remove(tripId);
      } else {
        _positions[tripId] = position;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: TripsRepository().watchTrips(widget.schoolId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const AsyncErrorView();

        final trips = (snapshot.data?.docs ?? const [])
            .map((doc) => SchoolTrip.fromMap(doc.id, doc.data()))
            .where(
              (trip) =>
                  trip.status == TripStatus.active ||
                  trip.status == TripStatus.starting ||
                  trip.status == TripStatus.paused ||
                  trip.status == TripStatus.emergency,
            )
            .toList();
        final tripsById = {for (final trip in trips) trip.id: trip};

        final center = _positions.values.isNotEmpty
            ? _positions.values.first
            : _fallbackCenter;

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: center, zoom: 11),
              markers: {
                for (final entry in _positions.entries)
                  Marker(
                    markerId: MarkerId(entry.key),
                    position: entry.value,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      tripsById[entry.key]?.status == TripStatus.emergency
                          ? BitmapDescriptor.hueRed
                          : BitmapDescriptor.hueAzure,
                    ),
                    infoWindow: InfoWindow(
                      title: tripsById[entry.key]?.routeName ?? 'Trip',
                      snippet: tripsById[entry.key]?.busPlateNumber,
                    ),
                  ),
              },
              zoomControlsEnabled: false,
            ),
            // Invisible: each one just subscribes to its trip's RTDB
            // location and reports back via onPosition, so N independent
            // live streams can feed one shared marker set above.
            for (final trip in trips)
              _TripLocationSubscriber(
                key: ValueKey(trip.id),
                schoolId: widget.schoolId,
                tripId: trip.id,
                onPosition: (position) => _updatePosition(trip.id, position),
              ),
            Positioned(
              left: 12,
              top: 12,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    trips.isEmpty
                        ? 'No trips on the road right now.'
                        : '${_positions.length} of ${trips.length} bus(es) broadcasting',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _ActiveEmergenciesPanel(schoolId: widget.schoolId),
            ),
          ],
        );
      },
    );
  }
}

/// A minimal, functional list of the school's currently active emergencies
/// with a resolve action — the business/data layer this backs
/// (EmergenciesRepository) needs *some* surface for an admin to actually
/// see and act on it; this reuses the same Card/ListTile styling already
/// used elsewhere on this tab rather than introducing anything new.
class _ActiveEmergenciesPanel extends StatelessWidget {
  const _ActiveEmergenciesPanel({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: EmergenciesRepository().watchActiveEmergencies(schoolId),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: docs.length,
              itemBuilder: (_, index) {
                final doc = docs[index];
                final emergency = SchoolEmergency.fromMap(doc.id, doc.data());

                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.warning_amber_rounded),
                  title: Text(
                    '${emergency.type.name} — ${DateFormat.jm().format(emergency.createdAt)}',
                  ),
                  subtitle: emergency.driverNote == null
                      ? null
                      : Text(emergency.driverNote!),
                  trailing: OutlinedButton(
                    onPressed: () => EmergenciesRepository()
                        .resolveEmergency(
                          schoolId: schoolId,
                          tripId: emergency.tripId,
                          emergencyId: emergency.id,
                        )
                        .then((_) => AppAnalytics.logEmergencyResolved(tripId: emergency.tripId))
                        .catchError((Object error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }),
                    child: const Text('Resolve'),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _TripLocationSubscriber extends StatefulWidget {
  const _TripLocationSubscriber({
    super.key,
    required this.schoolId,
    required this.tripId,
    required this.onPosition,
  });

  final String schoolId;
  final String tripId;
  final ValueChanged<LatLng?> onPosition;

  @override
  State<_TripLocationSubscriber> createState() => _TripLocationSubscriberState();
}

class _TripLocationSubscriberState extends State<_TripLocationSubscriber> {
  @override
  void dispose() {
    widget.onPosition(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: OpsTrackingRepository().watchTripLocation(
        schoolId: widget.schoolId,
        tripId: widget.tripId,
      ),
      builder: (context, snapshot) {
        final raw = snapshot.data?.snapshot.value;
        LatLng? position;
        if (raw is Map) {
          final data = Map<Object?, Object?>.from(raw);
          final latitude = (data['latitude'] as num?)?.toDouble();
          final longitude = (data['longitude'] as num?)?.toDouble();
          if (latitude != null && longitude != null) {
            position = LatLng(latitude, longitude);
          }
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onPosition(position);
        });
        return const SizedBox.shrink();
      },
    );
  }
}
