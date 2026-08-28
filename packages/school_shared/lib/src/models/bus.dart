class SchoolBus {
  const SchoolBus({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.plateNumber,
    required this.isActive,
  });

  final String id;
  final String schoolId;
  final String name;
  final String plateNumber;
  final bool isActive;

  factory SchoolBus.fromMap(
      String id,
      Map<String, dynamic> data,
      ) {
    return SchoolBus(
      id: id,
      schoolId: data['schoolId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      plateNumber: data['plateNumber'] as String? ?? '',
      isActive: data['isActive'] == true,
    );
  }
}