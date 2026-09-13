import 'package:flutter/widgets.dart';
import 'package:school_shared/school_shared.dart';

/// The emoji + bilingual label shown for each [CommunityPostCategory] on
/// the admin side — a deliberate duplicate of the parent app's own copy
/// (apps don't share UI code across each other, only through
/// `school_shared`, and this lookup is display-only), kept identical so a
/// post never shows a different category label to an admin than it showed
/// to the parent who filed it.
class CommunityCategoryUi {
  const CommunityCategoryUi._(this.emoji, this.en, this.ar, {this.fr, this.es});

  final String emoji;
  final String en;
  final String ar;
  final String? fr;
  final String? es;

  String label(BuildContext context) => S(en, ar, fr: fr, es: es).of(context);

  static const _byCategory = {
    CommunityPostCategory.busIssue: CommunityCategoryUi._(
      '🚌',
      'Bus issue',
      'مشكلة في الأتوبيس',
      fr: 'Problème de bus',
      es: 'Problema con el autobús',
    ),
    CommunityPostCategory.pickupPoint: CommunityCategoryUi._(
      '📍',
      'Pickup point issue',
      'مشكلة في نقطة الاستلام',
      fr: 'Problème de point de ramassage',
      es: 'Problema con el punto de recogida',
    ),
    CommunityPostCategory.delay: CommunityCategoryUi._(
      '⏰',
      'Delay',
      'تأخير',
      fr: 'Retard',
      es: 'Retraso',
    ),
    CommunityPostCategory.schoolIssue: CommunityCategoryUi._(
      '🏫',
      'School issue',
      'مشكلة في المدرسة',
      fr: 'Problème scolaire',
      es: 'Problema escolar',
    ),
    CommunityPostCategory.suggestion: CommunityCategoryUi._(
      '💡',
      'Suggestion',
      'اقتراح',
      fr: 'Suggestion',
      es: 'Sugerencia',
    ),
    CommunityPostCategory.question: CommunityCategoryUi._(
      '❓',
      'Question',
      'سؤال',
      fr: 'Question',
      es: 'Pregunta',
    ),
    CommunityPostCategory.complaint: CommunityCategoryUi._(
      '🚨',
      'Complaint',
      'شكوى',
      fr: 'Plainte',
      es: 'Queja',
    ),
    CommunityPostCategory.feedback: CommunityCategoryUi._(
      '⭐',
      'Feedback',
      'تقييم',
      fr: 'Avis',
      es: 'Comentario',
    ),
    CommunityPostCategory.other: CommunityCategoryUi._(
      '📌',
      'Other',
      'أخرى',
      fr: 'Autre',
      es: 'Otro',
    ),
  };

  static CommunityCategoryUi of(CommunityPostCategory category) =>
      _byCategory[category]!;
}

/// Bilingual status label for the admin moderation UI — [CommunityPost]
/// doesn't carry one itself since only the admin app ever needs to display
/// a status word (the parent feed only ever shows `active` posts at all).
String communityStatusLabel(BuildContext context, CommunityPostStatus status) {
  return switch (status) {
    CommunityPostStatus.active =>
      const S('Active', 'نشط', fr: 'Actif', es: 'Activo').of(context),
    CommunityPostStatus.hidden =>
      const S('Hidden', 'مخفي', fr: 'Masqué', es: 'Oculto').of(context),
    CommunityPostStatus.archived => const S(
      'Archived',
      'مؤرشف',
      fr: 'Archivé',
      es: 'Archivado',
    ).of(context),
    CommunityPostStatus.deleted =>
      const S('Deleted', 'محذوف', fr: 'Supprimé', es: 'Eliminado').of(context),
  };
}

/// Same relative-time formatting as the parent app's own copy — see that
/// file's doc comment for why this stays a small per-app duplicate rather
/// than a shared dependency.
String communityRelativeTime(BuildContext context, DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) {
    return const S(
      'Just now',
      'الآن',
      fr: "À l'instant",
      es: 'Ahora mismo',
    ).of(context);
  }
  if (diff.inMinutes < 60) {
    return S(
      '${diff.inMinutes}m ago',
      'منذ ${diff.inMinutes} د',
      fr: 'il y a ${diff.inMinutes} min',
      es: 'hace ${diff.inMinutes} min',
    ).of(context);
  }
  if (diff.inHours < 24) {
    return S(
      '${diff.inHours}h ago',
      'منذ ${diff.inHours} س',
      fr: 'il y a ${diff.inHours} h',
      es: 'hace ${diff.inHours} h',
    ).of(context);
  }
  if (diff.inDays < 7) {
    return S(
      '${diff.inDays}d ago',
      'منذ ${diff.inDays} يوم',
      fr: 'il y a ${diff.inDays} j',
      es: 'hace ${diff.inDays} d',
    ).of(context);
  }
  final weeks = diff.inDays ~/ 7;
  return S(
    '${weeks}w ago',
    'منذ $weeks أسبوع',
    fr: 'il y a $weeks sem.',
    es: 'hace $weeks sem.',
  ).of(context);
}
