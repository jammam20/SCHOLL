import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

/// Bilingual labels + status tones for the domain enums introduced by the
/// vehicle-management, incident, deviation and audit features. Kept in one
/// place (rather than repeated per screen) so an incident type reads
/// identically on the incidents table, the live map, the dashboard alert
/// feed and the staff read-only view — the same reason
/// `_tripStatusLabel`/`_tripStatusTone` already live once in
/// admin_home_page.dart.

String incidentTypeLabel(IncidentType type, BuildContext context) =>
    switch (type) {
      IncidentType.accident => const S('Accident', 'حادث').of(context),
      IncidentType.vehicleBreakdown =>
        const S('Vehicle breakdown', 'عطل في الأتوبيس').of(context),
      IncidentType.studentMedical =>
        const S('Student medical', 'حالة طبية لطالب').of(context),
      IncidentType.studentBehavior =>
        const S('Student behavior', 'سلوك طالب').of(context),
      IncidentType.routeBlocked =>
        const S('Route blocked', 'الطريق مقفول').of(context),
      IncidentType.policeEmergency =>
        const S('Police emergency', 'طوارئ شرطة').of(context),
      IncidentType.other => const S('Other', 'أخرى').of(context),
    };

IconData incidentTypeIcon(IncidentType type) => switch (type) {
  IncidentType.accident => Icons.car_crash_outlined,
  IncidentType.vehicleBreakdown => Icons.build_circle_outlined,
  IncidentType.studentMedical => Icons.medical_services_outlined,
  IncidentType.studentBehavior => Icons.psychology_alt_outlined,
  IncidentType.routeBlocked => Icons.block_outlined,
  IncidentType.policeEmergency => Icons.local_police_outlined,
  IncidentType.other => Icons.report_outlined,
};

String incidentStatusLabel(IncidentStatus status, BuildContext context) =>
    switch (status) {
      IncidentStatus.reported => const S('Reported', 'مُبلّغ عنه').of(context),
      IncidentStatus.acknowledged =>
        const S('Acknowledged', 'تم الاطلاع').of(context),
      IncidentStatus.resolved => const S('Resolved', 'تم الحل').of(context),
    };

/// `reported` is warning rather than error: an unreviewed incident needs
/// attention but isn't itself a failure — matching how `_tripStatusTone`
/// reserves `error` for genuine failures, not normal states.
StatusTone incidentStatusTone(IncidentStatus status) => switch (status) {
  IncidentStatus.reported => StatusTone.warning,
  IncidentStatus.acknowledged => StatusTone.info,
  IncidentStatus.resolved => StatusTone.success,
};

String maintenanceItemLabel(MaintenanceItemType type, BuildContext context) =>
    switch (type) {
      MaintenanceItemType.oilChange =>
        const S('Oil change', 'تغيير الزيت').of(context),
      MaintenanceItemType.tires => const S('Tires', 'الكاوتش').of(context),
      MaintenanceItemType.brakes => const S('Brakes', 'الفرامل').of(context),
      MaintenanceItemType.inspection =>
        const S('Inspection', 'الفحص الفني').of(context),
      MaintenanceItemType.insurance => const S('Insurance', 'التأمين').of(context),
      MaintenanceItemType.registration =>
        const S('Registration', 'رخصة التسيير').of(context),
      MaintenanceItemType.other => const S('Other', 'أخرى').of(context),
    };

IconData maintenanceItemIcon(MaintenanceItemType type) => switch (type) {
  MaintenanceItemType.oilChange => Icons.oil_barrel_outlined,
  MaintenanceItemType.tires => Icons.tire_repair_outlined,
  MaintenanceItemType.brakes => Icons.disc_full_outlined,
  MaintenanceItemType.inspection => Icons.fact_check_outlined,
  MaintenanceItemType.insurance => Icons.shield_outlined,
  MaintenanceItemType.registration => Icons.description_outlined,
  MaintenanceItemType.other => Icons.build_outlined,
};

String deviationStatusLabel(DeviationStatus status, BuildContext context) =>
    switch (status) {
      DeviationStatus.normal => const S('On route', 'على المسار').of(context),
      DeviationStatus.deviationStarted =>
        const S('Deviation started', 'بدأ الخروج عن المسار').of(context),
      DeviationStatus.deviating =>
        const S('Off route', 'خارج المسار').of(context),
      DeviationStatus.deviationEnded =>
        const S('Back on route', 'رجع للمسار').of(context),
    };

StatusTone deviationStatusTone(DeviationStatus status) => switch (status) {
  DeviationStatus.normal => StatusTone.success,
  DeviationStatus.deviationStarted => StatusTone.error,
  DeviationStatus.deviating => StatusTone.error,
  DeviationStatus.deviationEnded => StatusTone.neutral,
};

String emergencyTypeLabel(EmergencyType type, BuildContext context) =>
    switch (type) {
      EmergencyType.accident => const S('Accident', 'حادث').of(context),
      EmergencyType.vehicleBreakdown =>
        const S('Vehicle breakdown', 'عطل في الباص').of(context),
      EmergencyType.medical => const S('Medical', 'حالة طبية').of(context),
      EmergencyType.security => const S('Security', 'أمنية').of(context),
      EmergencyType.other => const S('Other', 'أخرى').of(context),
    };

/// The audit trail's `action` strings are free-form well-known constants
/// (see [AuditActions]), so an unrecognized one is rendered as its raw
/// value with underscores turned into spaces rather than dropped.
String auditActionLabel(String action, BuildContext context) =>
    switch (action) {
      AuditActions.tripStarted => const S('Trip started', 'بدأت الرحلة').of(context),
      AuditActions.tripCompleted =>
        const S('Trip completed', 'اكتملت الرحلة').of(context),
      AuditActions.tripCancelled =>
        const S('Trip cancelled', 'أُلغيت الرحلة').of(context),
      AuditActions.stopReached =>
        const S('Stop reached', 'الوصول لمحطة').of(context),
      AuditActions.studentBoarded =>
        const S('Student boarded', 'طالب ركب').of(context),
      AuditActions.studentDroppedOff =>
        const S('Student dropped off', 'طالب نزل').of(context),
      AuditActions.deviationStarted =>
        const S('Deviation started', 'بدأ الخروج عن المسار').of(context),
      AuditActions.deviationEnded =>
        const S('Deviation ended', 'انتهى الخروج عن المسار').of(context),
      AuditActions.incidentReported =>
        const S('Incident reported', 'تم الإبلاغ عن حادثة').of(context),
      AuditActions.incidentAcknowledged =>
        const S('Incident acknowledged', 'تم الاطلاع على الحادثة').of(context),
      AuditActions.incidentResolved =>
        const S('Incident resolved', 'تم حل الحادثة').of(context),
      AuditActions.emergencyRaised =>
        const S('Emergency raised', 'تم رفع حالة طوارئ').of(context),
      AuditActions.emergencyResolved =>
        const S('Emergency resolved', 'تم حل حالة الطوارئ').of(context),
      AuditActions.busReassigned =>
        const S('Bus reassigned', 'تم تغيير الأتوبيس').of(context),
      AuditActions.driverReassigned =>
        const S('Driver reassigned', 'تم تغيير السائق').of(context),
      AuditActions.pickupVerified =>
        const S('Pickup verified', 'تم تأكيد الاستلام').of(context),
      AuditActions.pickupVerificationFailed =>
        const S('Pickup verification failed', 'فشل تأكيد الاستلام').of(context),
      AuditActions.inspectionCompleted =>
        const S('Inspection completed', 'اكتمل الفحص').of(context),
      AuditActions.inspectionFailed =>
        const S('Inspection failed', 'فشل الفحص').of(context),
      AuditActions.studentLocationRequestSubmitted =>
        const S('Location request submitted', 'تم إرسال طلب الموقع').of(context),
      AuditActions.studentLocationRequestAccepted =>
        const S('Location request accepted', 'تم قبول طلب الموقع').of(context),
      AuditActions.studentLocationRequestRejected =>
        const S('Location request rejected', 'تم رفض طلب الموقع').of(context),
      AuditActions.studentRequestRejected =>
        const S('Student request rejected', 'تم رفض طلب الطالب').of(context),
      _ => action.replaceAll('_', ' '),
    };

/// Actions that describe something going wrong get an alerting tone in the
/// audit table; ordinary operational actions stay neutral so the genuinely
/// notable rows stand out when scanning.
StatusTone auditActionTone(String action) => switch (action) {
  AuditActions.emergencyRaised => StatusTone.emergency,
  AuditActions.incidentReported ||
  AuditActions.deviationStarted ||
  AuditActions.pickupVerificationFailed ||
  AuditActions.inspectionFailed => StatusTone.warning,
  AuditActions.emergencyResolved ||
  AuditActions.incidentResolved ||
  AuditActions.tripCompleted ||
  AuditActions.inspectionCompleted => StatusTone.success,
  AuditActions.busReassigned ||
  AuditActions.driverReassigned ||
  AuditActions.incidentAcknowledged ||
  AuditActions.studentLocationRequestAccepted => StatusTone.info,
  AuditActions.studentLocationRequestRejected ||
  AuditActions.studentRequestRejected => StatusTone.warning,
  _ => StatusTone.neutral,
};

String reassignmentTypeLabel(ReassignmentType type, BuildContext context) =>
    switch (type) {
      ReassignmentType.busReassigned =>
        const S('Bus reassigned', 'تم تغيير الأتوبيس').of(context),
      ReassignmentType.driverReassigned =>
        const S('Driver reassigned', 'تم تغيير السائق').of(context),
      ReassignmentType.routeChanged =>
        const S('Route changed', 'تم تغيير الخط').of(context),
      ReassignmentType.stopSkipped =>
        const S('Stop skipped', 'تم تخطي محطة').of(context),
    };

/// Maps a member's stored `status` string (drivers/parents — `pending` /
/// `approved` / `suspended` / `rejected`, see `DriversRepository` /
/// `ParentsRepository`) onto the one shared status pattern used everywhere
/// else in the product, per `design-system/MASTER.md` §2/§8. Promoted out
/// of `admin_home_page.dart` (where it was private) so DriverDetailPage
/// can show the exact same status badge without a second copy.
StatusTone memberStatusTone(String status) {
  switch (status) {
    case 'approved':
      return StatusTone.success;
    case 'suspended':
    case 'rejected':
      return StatusTone.error;
    case 'pending':
    default:
      return StatusTone.warning;
  }
}

String memberStatusLabel(BuildContext context, String status) {
  switch (status) {
    case 'approved':
      return const S('Approved', 'مقبول').of(context);
    case 'suspended':
      return const S('Suspended', 'موقوف').of(context);
    case 'rejected':
      return const S('Rejected', 'مرفوض').of(context);
    case 'pending':
    default:
      return const S('Pending', 'قيد الانتظار').of(context);
  }
}

// toneColor(AppColorTokens, StatusTone) moved to
// packages/school_shared/lib/src/design/components/status_badge.dart —
// every call site here already imports school_shared.dart, so nothing
// needed to change beyond removing this now-duplicate definition.

/// "in 6 days" / "3 days overdue" / "today", for every due-date the
/// vehicle and driver management screens surface. Deliberately whole-day
/// granularity: an insurance or license expiry is a calendar fact, so an
/// hours-level countdown would imply a precision the underlying date
/// doesn't have.
String relativeDueLabel(DateTime due, DateTime now, BuildContext context) {
  final days = DateTime(
    due.year,
    due.month,
    due.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;

  if (days == 0) return const S('Due today', 'مستحق النهاردة').of(context);
  if (days == 1) return const S('Due tomorrow', 'مستحق بكرة').of(context);
  if (days > 1) return S('In $days days', 'خلال $days يوم').of(context);
  final overdue = -days;
  if (overdue == 1) {
    return const S('1 day overdue', 'متأخر يوم').of(context);
  }
  return S('$overdue days overdue', 'متأخر $overdue يوم').of(context);
}

/// The shared amber/red/neutral rule behind every expiry badge in the
/// vehicle and driver management screens: overdue is `error`, due within
/// [within] is `warning`, anything further out is `neutral`.
StatusTone dueDateTone(
  DateTime? due,
  DateTime now, {
  Duration within = const Duration(days: 30),
}) {
  if (due == null) return StatusTone.neutral;
  if (due.isBefore(now)) return StatusTone.error;
  if (due.difference(now) <= within) return StatusTone.warning;
  return StatusTone.success;
}
