class School {
  const School({
    required this.id,
    required this.name,
    required this.code,
    required this.isActive,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String code;
  final bool isActive;

  // The school's own location — every trip's fixed final stop. Writable
  // only through the updateSchoolLocation callable (firestore.rules
  // restricts direct writes on `schools/{id}` to system admins).
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  factory School.fromMap(
      String id,
      Map<String, dynamic> data,
      ) {
    return School(
      id: id,
      name: data['name'] as String? ?? '',
      code: data['code'] as String? ?? '',
      isActive: data['isActive'] == true,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }
}