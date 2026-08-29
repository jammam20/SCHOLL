import '../enums/maintenance_item_type.dart';

/// One maintenance/document item for a bus — `dueAt` drives the
/// due-soon/overdue warnings on the vehicle management screen;
/// `completedAt` non-null means this instance of the item is done (a new
/// record is created for the next cycle rather than this one being reused,
/// so history is preserved).
class MaintenanceRecord {
  const MaintenanceRecord({
    required this.id,
    required this.schoolId,
    required this.busId,
    required this.itemType,
    required this.dueAt,
    this.description = '',
    this.completedAt,
    this.notes,
  });

  final String id;
  final String schoolId;
  final String busId;
  final MaintenanceItemType itemType;
  final String description;
  final DateTime dueAt;
  final DateTime? completedAt;
  final String? notes;

  bool get isCompleted => completedAt != null;

  /// Overdue only matters for items not yet completed — a completed record
  /// is history, not an open warning.
  bool isOverdue(DateTime now) => !isCompleted && dueAt.isBefore(now);

  bool isDueSoon(DateTime now, {Duration within = const Duration(days: 14)}) =>
      !isCompleted && !isOverdue(now) && dueAt.difference(now) <= within;

  factory MaintenanceRecord.fromMap(String id, Map<String, dynamic> data) {
    return MaintenanceRecord(
      id: id,
      schoolId: data['schoolId'] as String? ?? '',
      busId: data['busId'] as String? ?? '',
      itemType: MaintenanceItemTypeX.tryParse(data['itemType']) ?? MaintenanceItemType.other,
      description: data['description'] as String? ?? '',
      dueAt: _asDateTime(data['dueAt']) ?? DateTime.now(),
      completedAt: _asDateTime(data['completedAt']),
      notes: data['notes'] as String?,
    );
  }

  static DateTime? _asDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      final dynamic dynamicValue = value;
      final result = dynamicValue.toDate();
      return result is DateTime ? result : null;
    } catch (_) {
      return null;
    }
  }
}
