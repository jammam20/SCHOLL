class SchoolRoute {
  const SchoolRoute({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.isActive,
    this.deviationToleranceMeters = 400,
    this.outboundScheduledMinutes,
    this.returnScheduledMinutes,
  });

  final String id;
  final String schoolId;
  final String name;
  final bool isActive;

  // How far (meters) a bus may be from its trip's expected stop-to-stop
  // path before it's flagged as a route deviation (Feature: Route
  // Deviation Detection). Defaults to a sensible corridor width for
  // street-level GPS noise + minor detours; admin-configurable per route
  // since a rural route and a dense-urban route need different tolerances.
  final double deviationToleranceMeters;

  // Feature: two daily trips. Each direction's fixed daily time-of-day, as
  // minutes since UTC midnight — deliberately UTC, not the school's local
  // midnight: firestore.rules' absence-cutoff check only has
  // `request.time.date()` to work with, which is always UTC midnight, so
  // this must be pre-converted (local wall-clock time -> UTC) at save time
  // for that comparison to land on the right moment. Not a specific trip's
  // `scheduledAt`, but the recurring schedule new trips are generated at.
  // Null means that direction isn't run on this route. Storing this on the
  // route (rather than duplicating a whole second route) is what lets a
  // security rule compute an absence cutoff for "today's trip on this
  // route" without needing to know a specific trip document's id.
  final int? outboundScheduledMinutes;
  final int? returnScheduledMinutes;

  factory SchoolRoute.fromMap(
      String id,
      Map<String, dynamic> data,
      ) {
    return SchoolRoute(
      id: id,
      schoolId: data['schoolId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      isActive: data['isActive'] == true,
      deviationToleranceMeters:
          (data['deviationToleranceMeters'] as num?)?.toDouble() ?? 400,
      outboundScheduledMinutes:
          (data['outboundScheduledMinutes'] as num?)?.toInt(),
      returnScheduledMinutes:
          (data['returnScheduledMinutes'] as num?)?.toInt(),
    );
  }
}
