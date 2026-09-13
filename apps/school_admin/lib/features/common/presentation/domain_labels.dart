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
      IncidentType.accident => const S(
        'Accident',
        'حادث',
        fr: 'Accident',
        es: 'Accidente',
      ).of(context),
      IncidentType.vehicleBreakdown => const S(
        'Vehicle breakdown',
        'عطل في الأتوبيس',
        fr: 'Panne du véhicule',
        es: 'Avería del vehículo',
      ).of(context),
      IncidentType.studentMedical => const S(
        'Student medical',
        'حالة طبية لطالب',
        fr: 'Urgence médicale élève',
        es: 'Emergencia médica de alumno',
      ).of(context),
      IncidentType.studentBehavior => const S(
        'Student behavior',
        'سلوك طالب',
        fr: "Comportement d'un élève",
        es: 'Comportamiento de alumno',
      ).of(context),
      IncidentType.routeBlocked => const S(
        'Route blocked',
        'الطريق مقفول',
        fr: 'Itinéraire bloqué',
        es: 'Ruta bloqueada',
      ).of(context),
      IncidentType.policeEmergency => const S(
        'Police emergency',
        'طوارئ شرطة',
        fr: 'Urgence police',
        es: 'Emergencia policial',
      ).of(context),
      IncidentType.other => const S(
        'Other',
        'أخرى',
        fr: 'Autre',
        es: 'Otro',
      ).of(context),
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
      IncidentStatus.reported => const S(
        'Reported',
        'مُبلّغ عنه',
        fr: 'Signalé',
        es: 'Reportado',
      ).of(context),
      IncidentStatus.acknowledged => const S(
        'Acknowledged',
        'تم الاطلاع',
        fr: 'Pris en compte',
        es: 'Reconocido',
      ).of(context),
      IncidentStatus.resolved => const S(
        'Resolved',
        'تم الحل',
        fr: 'Résolu',
        es: 'Resuelto',
      ).of(context),
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
      MaintenanceItemType.oilChange => const S(
        'Oil change',
        'تغيير الزيت',
        fr: "Vidange d'huile",
        es: 'Cambio de aceite',
      ).of(context),
      MaintenanceItemType.tires => const S(
        'Tires',
        'الكاوتش',
        fr: 'Pneus',
        es: 'Neumáticos',
      ).of(context),
      MaintenanceItemType.brakes => const S(
        'Brakes',
        'الفرامل',
        fr: 'Freins',
        es: 'Frenos',
      ).of(context),
      MaintenanceItemType.inspection => const S(
        'Inspection',
        'الفحص الفني',
        fr: 'Inspection',
        es: 'Inspección',
      ).of(context),
      MaintenanceItemType.insurance => const S(
        'Insurance',
        'التأمين',
        fr: 'Assurance',
        es: 'Seguro',
      ).of(context),
      MaintenanceItemType.registration => const S(
        'Registration',
        'رخصة التسيير',
        fr: 'Immatriculation',
        es: 'Matriculación',
      ).of(context),
      MaintenanceItemType.other => const S(
        'Other',
        'أخرى',
        fr: 'Autre',
        es: 'Otro',
      ).of(context),
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
      DeviationStatus.normal => const S(
        'On route',
        'على المسار',
        fr: "Sur l'itinéraire",
        es: 'En ruta',
      ).of(context),
      DeviationStatus.deviationStarted => const S(
        'Deviation started',
        'بدأ الخروج عن المسار',
        fr: 'Début de déviation',
        es: 'Inicio de desvío',
      ).of(context),
      DeviationStatus.deviating => const S(
        'Off route',
        'خارج المسار',
        fr: 'Hors itinéraire',
        es: 'Fuera de ruta',
      ).of(context),
      DeviationStatus.deviationEnded => const S(
        'Back on route',
        'رجع للمسار',
        fr: "De retour sur l'itinéraire",
        es: 'De vuelta en ruta',
      ).of(context),
    };

StatusTone deviationStatusTone(DeviationStatus status) => switch (status) {
  DeviationStatus.normal => StatusTone.success,
  DeviationStatus.deviationStarted => StatusTone.error,
  DeviationStatus.deviating => StatusTone.error,
  DeviationStatus.deviationEnded => StatusTone.neutral,
};

String emergencyTypeLabel(EmergencyType type, BuildContext context) =>
    switch (type) {
      EmergencyType.accident => const S(
        'Accident',
        'حادث',
        fr: 'Accident',
        es: 'Accidente',
      ).of(context),
      EmergencyType.vehicleBreakdown => const S(
        'Vehicle breakdown',
        'عطل في الباص',
        fr: 'Panne du véhicule',
        es: 'Avería del vehículo',
      ).of(context),
      EmergencyType.medical => const S(
        'Medical',
        'حالة طبية',
        fr: 'Médicale',
        es: 'Médica',
      ).of(context),
      EmergencyType.security => const S(
        'Security',
        'أمنية',
        fr: 'Sécurité',
        es: 'Seguridad',
      ).of(context),
      EmergencyType.other => const S(
        'Other',
        'أخرى',
        fr: 'Autre',
        es: 'Otro',
      ).of(context),
    };

/// The audit trail's `action` strings are free-form well-known constants
/// (see [AuditActions]), so an unrecognized one is rendered as its raw
/// value with underscores turned into spaces rather than dropped.
String auditActionLabel(String action, BuildContext context) =>
    switch (action) {
      AuditActions.tripStarted => const S(
        'Trip started',
        'بدأت الرحلة',
        fr: 'Trajet démarré',
        es: 'Viaje iniciado',
      ).of(context),
      AuditActions.tripCompleted => const S(
        'Trip completed',
        'اكتملت الرحلة',
        fr: 'Trajet terminé',
        es: 'Viaje completado',
      ).of(context),
      AuditActions.tripCancelled => const S(
        'Trip cancelled',
        'أُلغيت الرحلة',
        fr: 'Trajet annulé',
        es: 'Viaje cancelado',
      ).of(context),
      AuditActions.stopReached => const S(
        'Stop reached',
        'الوصول لمحطة',
        fr: 'Arrêt atteint',
        es: 'Parada alcanzada',
      ).of(context),
      AuditActions.studentBoarded => const S(
        'Student boarded',
        'طالب ركب',
        fr: 'Élève monté',
        es: 'Alumno abordó',
      ).of(context),
      AuditActions.studentDroppedOff => const S(
        'Student dropped off',
        'طالب نزل',
        fr: 'Élève déposé',
        es: 'Alumno bajó',
      ).of(context),
      AuditActions.deviationStarted => const S(
        'Deviation started',
        'بدأ الخروج عن المسار',
        fr: 'Début de déviation',
        es: 'Inicio de desvío',
      ).of(context),
      AuditActions.deviationEnded => const S(
        'Deviation ended',
        'انتهى الخروج عن المسار',
        fr: 'Fin de déviation',
        es: 'Fin de desvío',
      ).of(context),
      AuditActions.incidentReported => const S(
        'Incident reported',
        'تم الإبلاغ عن حادثة',
        fr: 'Incident signalé',
        es: 'Incidente reportado',
      ).of(context),
      AuditActions.incidentAcknowledged => const S(
        'Incident acknowledged',
        'تم الاطلاع على الحادثة',
        fr: 'Incident pris en compte',
        es: 'Incidente reconocido',
      ).of(context),
      AuditActions.incidentResolved => const S(
        'Incident resolved',
        'تم حل الحادثة',
        fr: 'Incident résolu',
        es: 'Incidente resuelto',
      ).of(context),
      AuditActions.emergencyRaised => const S(
        'Emergency raised',
        'تم رفع حالة طوارئ',
        fr: 'Urgence déclenchée',
        es: 'Emergencia activada',
      ).of(context),
      AuditActions.emergencyResolved => const S(
        'Emergency resolved',
        'تم حل حالة الطوارئ',
        fr: 'Urgence résolue',
        es: 'Emergencia resuelta',
      ).of(context),
      AuditActions.busReassigned => const S(
        'Bus reassigned',
        'تم تغيير الأتوبيس',
        fr: 'Bus réaffecté',
        es: 'Autobús reasignado',
      ).of(context),
      AuditActions.driverReassigned => const S(
        'Driver reassigned',
        'تم تغيير السائق',
        fr: 'Chauffeur réaffecté',
        es: 'Conductor reasignado',
      ).of(context),
      AuditActions.pickupVerified => const S(
        'Pickup verified',
        'تم تأكيد الاستلام',
        fr: 'Prise en charge vérifiée',
        es: 'Recogida verificada',
      ).of(context),
      AuditActions.pickupVerificationFailed => const S(
        'Pickup verification failed',
        'فشل تأكيد الاستلام',
        fr: 'Échec de vérification de prise en charge',
        es: 'Fallo al verificar la recogida',
      ).of(context),
      AuditActions.inspectionCompleted => const S(
        'Inspection completed',
        'اكتمل الفحص',
        fr: 'Inspection terminée',
        es: 'Inspección completada',
      ).of(context),
      AuditActions.inspectionFailed => const S(
        'Inspection failed',
        'فشل الفحص',
        fr: "Échec de l'inspection",
        es: 'Inspección fallida',
      ).of(context),
      AuditActions.studentLocationRequestSubmitted => const S(
        'Location request submitted',
        'تم إرسال طلب الموقع',
        fr: 'Demande de localisation envoyée',
        es: 'Solicitud de ubicación enviada',
      ).of(context),
      AuditActions.studentLocationRequestAccepted => const S(
        'Location request accepted',
        'تم قبول طلب الموقع',
        fr: 'Demande de localisation acceptée',
        es: 'Solicitud de ubicación aceptada',
      ).of(context),
      AuditActions.studentLocationRequestRejected => const S(
        'Location request rejected',
        'تم رفض طلب الموقع',
        fr: 'Demande de localisation refusée',
        es: 'Solicitud de ubicación rechazada',
      ).of(context),
      AuditActions.studentRequestRejected => const S(
        'Student request rejected',
        'تم رفض طلب الطالب',
        fr: "Demande de l'élève refusée",
        es: 'Solicitud del alumno rechazada',
      ).of(context),
      AuditActions.tripPaused => const S(
        'Trip paused',
        'توقفت الرحلة مؤقتًا',
        fr: 'Trajet en pause',
        es: 'Viaje en pausa',
      ).of(context),
      AuditActions.tripResumed => const S(
        'Trip resumed',
        'استؤنفت الرحلة',
        fr: 'Trajet repris',
        es: 'Viaje reanudado',
      ).of(context),
      AuditActions.boardingRejectedCapacity => const S(
        'Boarding rejected — bus full',
        'رُفض الركوب — الأتوبيس ممتلئ',
        fr: 'Montée refusée — bus complet',
        es: 'Embarque rechazado — autobús lleno',
      ).of(context),
      AuditActions.driverApproved => const S(
        'Driver approved',
        'تمت الموافقة على السائق',
        fr: 'Chauffeur approuvé',
        es: 'Conductor aprobado',
      ).of(context),
      AuditActions.driverSuspended => const S(
        'Driver suspended',
        'تم إيقاف السائق',
        fr: 'Chauffeur suspendu',
        es: 'Conductor suspendido',
      ).of(context),
      AuditActions.driverRejected => const S(
        'Driver rejected',
        'تم رفض السائق',
        fr: 'Chauffeur refusé',
        es: 'Conductor rechazado',
      ).of(context),
      AuditActions.parentApproved => const S(
        'Parent approved',
        'تمت الموافقة على ولي الأمر',
        fr: 'Parent approuvé',
        es: 'Padre/madre aprobado',
      ).of(context),
      AuditActions.parentSuspended => const S(
        'Parent suspended',
        'تم إيقاف ولي الأمر',
        fr: 'Parent suspendu',
        es: 'Padre/madre suspendido',
      ).of(context),
      AuditActions.parentRejected => const S(
        'Parent rejected',
        'تم رفض ولي الأمر',
        fr: 'Parent refusé',
        es: 'Padre/madre rechazado',
      ).of(context),
      AuditActions.studentApproved => const S(
        'Student approved',
        'تمت الموافقة على الطالب',
        fr: 'Élève approuvé',
        es: 'Alumno aprobado',
      ).of(context),
      AuditActions.studentCreated => const S(
        'Student created',
        'تم إنشاء طالب',
        fr: 'Élève créé',
        es: 'Alumno creado',
      ).of(context),
      AuditActions.studentUpdated => const S(
        'Student updated',
        'تم تعديل بيانات الطالب',
        fr: 'Élève modifié',
        es: 'Alumno actualizado',
      ).of(context),
      AuditActions.studentArchived => const S(
        'Student archived',
        'تمت أرشفة الطالب',
        fr: 'Élève archivé',
        es: 'Alumno archivado',
      ).of(context),
      AuditActions.studentRestored => const S(
        'Student restored',
        'تمت استعادة الطالب',
        fr: 'Élève restauré',
        es: 'Alumno restaurado',
      ).of(context),
      AuditActions.busCreated => const S(
        'Bus created',
        'تم إنشاء أتوبيس',
        fr: 'Bus créé',
        es: 'Autobús creado',
      ).of(context),
      AuditActions.busUpdated => const S(
        'Bus updated',
        'تم تعديل بيانات الأتوبيس',
        fr: 'Bus modifié',
        es: 'Autobús actualizado',
      ).of(context),
      AuditActions.busArchived => const S(
        'Bus archived',
        'تمت أرشفة الأتوبيس',
        fr: 'Bus archivé',
        es: 'Autobús archivado',
      ).of(context),
      AuditActions.busRestored => const S(
        'Bus restored',
        'تمت استعادة الأتوبيس',
        fr: 'Bus restauré',
        es: 'Autobús restaurado',
      ).of(context),
      AuditActions.routeCreated => const S(
        'Route created',
        'تم إنشاء خط',
        fr: 'Itinéraire créé',
        es: 'Ruta creada',
      ).of(context),
      AuditActions.routeUpdated => const S(
        'Route updated',
        'تم تعديل الخط',
        fr: 'Itinéraire modifié',
        es: 'Ruta actualizada',
      ).of(context),
      AuditActions.routeArchived => const S(
        'Route archived',
        'تمت أرشفة الخط',
        fr: 'Itinéraire archivé',
        es: 'Ruta archivada',
      ).of(context),
      AuditActions.routeRestored => const S(
        'Route restored',
        'تمت استعادة الخط',
        fr: 'Itinéraire restauré',
        es: 'Ruta restaurada',
      ).of(context),
      AuditActions.tripCreated => const S(
        'Trip created',
        'تم إنشاء رحلة',
        fr: 'Trajet créé',
        es: 'Viaje creado',
      ).of(context),
      AuditActions.tripCancelledByAdmin => const S(
        'Trip cancelled by admin',
        'ألغى الأدمن الرحلة',
        fr: "Trajet annulé par l'administrateur",
        es: 'Viaje cancelado por el administrador',
      ).of(context),
      AuditActions.schoolSettingsUpdated => const S(
        'School settings updated',
        'تم تعديل إعدادات المدرسة',
        fr: "Paramètres de l'école mis à jour",
        es: 'Configuración de la escuela actualizada',
      ).of(context),
      AuditActions.schoolLocationUpdated => const S(
        'School location updated',
        'تم تعديل موقع المدرسة',
        fr: "Emplacement de l'école mis à jour",
        es: 'Ubicación de la escuela actualizada',
      ).of(context),
      AuditActions.schoolCreated => const S(
        'School created',
        'تم إنشاء مدرسة',
        fr: 'École créée',
        es: 'Escuela creada',
      ).of(context),
      AuditActions.schoolActivated => const S(
        'School activated',
        'تم تفعيل المدرسة',
        fr: 'École activée',
        es: 'Escuela activada',
      ).of(context),
      AuditActions.schoolDeactivated => const S(
        'School deactivated',
        'تم إيقاف المدرسة',
        fr: 'École désactivée',
        es: 'Escuela desactivada',
      ).of(context),
      AuditActions.schoolAdminApproved => const S(
        'School admin approved',
        'تمت الموافقة على أدمن المدرسة',
        fr: "Administrateur d'école approuvé",
        es: 'Administrador escolar aprobado',
      ).of(context),
      AuditActions.schoolAdminRejected => const S(
        'School admin rejected',
        'تم رفض أدمن المدرسة',
        fr: "Administrateur d'école refusé",
        es: 'Administrador escolar rechazado',
      ).of(context),
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
  AuditActions.studentRequestRejected ||
  AuditActions.boardingRejectedCapacity ||
  AuditActions.driverRejected ||
  AuditActions.driverSuspended ||
  AuditActions.parentRejected ||
  AuditActions.parentSuspended ||
  AuditActions.tripCancelledByAdmin ||
  AuditActions.schoolDeactivated ||
  AuditActions.schoolAdminRejected => StatusTone.warning,
  AuditActions.driverApproved ||
  AuditActions.parentApproved ||
  AuditActions.studentApproved ||
  AuditActions.schoolActivated ||
  AuditActions.schoolAdminApproved => StatusTone.success,
  _ => StatusTone.neutral,
};

String reassignmentTypeLabel(ReassignmentType type, BuildContext context) =>
    switch (type) {
      ReassignmentType.busReassigned => const S(
        'Bus reassigned',
        'تم تغيير الأتوبيس',
        fr: 'Bus réaffecté',
        es: 'Autobús reasignado',
      ).of(context),
      ReassignmentType.driverReassigned => const S(
        'Driver reassigned',
        'تم تغيير السائق',
        fr: 'Chauffeur réaffecté',
        es: 'Conductor reasignado',
      ).of(context),
      ReassignmentType.routeChanged => const S(
        'Route changed',
        'تم تغيير الخط',
        fr: "Itinéraire modifié",
        es: 'Ruta cambiada',
      ).of(context),
      ReassignmentType.stopSkipped => const S(
        'Stop skipped',
        'تم تخطي محطة',
        fr: 'Arrêt sauté',
        es: 'Parada omitida',
      ).of(context),
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
      return const S(
        'Approved',
        'مقبول',
        fr: 'Approuvé',
        es: 'Aprobado',
      ).of(context);
    case 'suspended':
      return const S(
        'Suspended',
        'موقوف',
        fr: 'Suspendu',
        es: 'Suspendido',
      ).of(context);
    case 'rejected':
      return const S(
        'Rejected',
        'مرفوض',
        fr: 'Refusé',
        es: 'Rechazado',
      ).of(context);
    case 'pending':
    default:
      return const S(
        'Pending',
        'قيد الانتظار',
        fr: 'En attente',
        es: 'Pendiente',
      ).of(context);
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

  if (days == 0) {
    return const S(
      'Due today',
      'مستحق النهاردة',
      fr: "Échéance aujourd'hui",
      es: 'Vence hoy',
    ).of(context);
  }
  if (days == 1) {
    return const S(
      'Due tomorrow',
      'مستحق بكرة',
      fr: 'Échéance demain',
      es: 'Vence mañana',
    ).of(context);
  }
  if (days > 1) {
    return S(
      'In $days days',
      'خلال $days يوم',
      fr: 'Dans $days jours',
      es: 'En $days días',
    ).of(context);
  }
  final overdue = -days;
  if (overdue == 1) {
    return const S(
      '1 day overdue',
      'متأخر يوم',
      fr: '1 jour de retard',
      es: '1 día de retraso',
    ).of(context);
  }
  return S(
    '$overdue days overdue',
    'متأخر $overdue يوم',
    fr: '$overdue jours de retard',
    es: '$overdue días de retraso',
  ).of(context);
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
