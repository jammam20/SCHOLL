class SchoolRoute {
  const SchoolRoute({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.isActive,
    this.deviationToleranceMeters = 400,
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
    );
  }
}
