import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../../trips/data/trips_repository.dart';
import 'live_trip_map.dart';

/// The live map on its own, filling the screen — for the moment a parent
/// stops skimming the home card and actually wants to watch the bus.
///
/// It re-opens the same `watchLatestTripForRoute` stream the home card uses
/// rather than being handed a frozen [SchoolTrip]: a trip can be paused,
/// resumed, completed or cancelled while this page is open, and the ETA
/// engine's answer depends on that status. Reading it live here means the
/// full-screen view can never sit there quoting an ETA for a trip that
/// ended two minutes ago.
class LiveTripMapPage extends StatelessWidget {
  const LiveTripMapPage({
    super.key,
    required this.schoolId,
    required this.routeId,
    required this.student,
  });

  final String schoolId;
  final String routeId;
  final Student student;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              S(
                'Tracking ${student.name}',
                'متابعة ${student.name}',
                fr: 'Suivi de ${student.name}',
                es: 'Siguiendo a ${student.name}',
              ).of(
                context,
              ),
            ),
            Text(
              const S(
                'Live bus location',
                'موقع الأتوبيس المباشر',
                fr: 'Position du bus en direct',
                es: 'Ubicación del autobús en vivo',
              ).of(
                context,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: TripsRepository().watchLatestTripForRoute(
          schoolId: schoolId,
          routeId: routeId,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorStateView(
              message: const S(
                "Couldn't load this trip — check your connection and try "
                    'again.',
                'معرفناش نحمّل الرحلة دي — اتأكد من الاتصال وجرب تاني.',
                fr:
                    'Impossible de charger ce trajet — vérifiez votre '
                    'connexion et réessayez.',
                es:
                    'No se pudo cargar este viaje: revise su conexión e '
                    'inténtelo de nuevo.',
              ).of(context),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) return _noLiveTrip(context);

          final trip = SchoolTrip.fromMap(docs.first.id, docs.first.data());
          // The same guard the home card applies: a finished or cancelled
          // trip has nothing live left to follow.
          if (trip.status == TripStatus.completed ||
              trip.status == TripStatus.cancelled ||
              trip.status == TripStatus.scheduled) {
            return _noLiveTrip(context);
          }

          return LiveTripMap(
            schoolId: schoolId,
            tripId: trip.id,
            tripStatus: trip.status,
            student: student,
            fillAvailableSpace: true,
          );
        },
      ),
    );
  }

  Widget _noLiveTrip(BuildContext context) => EmptyStateView(
    icon: Icons.directions_bus_outlined,
    title: const S(
      'Nothing to track right now',
      'مفيش حاجة نتابعها دلوقتي',
      fr: 'Rien à suivre pour le moment',
      es: 'Nada que seguir en este momento',
    ).of(context),
    message: const S(
      "This route's bus isn't out on a trip at the moment.",
      'أتوبيس الخط ده مش في رحلة دلوقتي.',
      fr: "Le bus de ce trajet n'est pas en route en ce moment.",
      es: 'El autobús de esta ruta no está en viaje en este momento.',
    ).of(context),
    actionLabel: const S(
      'Back',
      'رجوع',
      fr: 'Retour',
      es: 'Atrás',
    ).of(context),
    onAction: () => Navigator.of(context).maybePop(),
  );
}
