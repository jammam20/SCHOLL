class SchoolRoute {
  const SchoolRoute({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.isActive,
  });

  final String id;
  final String schoolId;
  final String name;
  final bool isActive;

  factory SchoolRoute.fromMap(
      String id,
      Map<String, dynamic> data,
      ) {
    return SchoolRoute(
      id: id,
      schoolId: data['schoolId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      isActive: data['isActive'] == true,
    );
  }
}