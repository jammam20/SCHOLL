import 'package:flutter/widgets.dart';
import 'package:school_shared/school_shared.dart';

/// The emoji + bilingual label shown for each [CommunityPostCategory] —
/// kept as one small lookup so the composer, the feed chip, and the filter
/// row can never drift into showing three different labels for the same
/// category.
class CommunityCategoryUi {
  const CommunityCategoryUi._(this.emoji, this.en, this.ar, this.fr, this.es);

  final String emoji;
  final String en;
  final String ar;
  final String fr;
  final String es;

  String label(BuildContext context) => S(en, ar, fr: fr, es: es).of(context);

  static const _byCategory = {
    CommunityPostCategory.busIssue: CommunityCategoryUi._(
      '🚌',
      'Bus issue',
      'مشكلة في الأتوبيس',
      'Problème de bus',
      'Problema con el autobús',
    ),
    CommunityPostCategory.pickupPoint: CommunityCategoryUi._(
      '📍',
      'Pickup point issue',
      'مشكلة في نقطة الاستلام',
      'Problème au point de ramassage',
      'Problema en el punto de recogida',
    ),
    CommunityPostCategory.delay: CommunityCategoryUi._(
      '⏰',
      'Delay',
      'تأخير',
      'Retard',
      'Retraso',
    ),
    CommunityPostCategory.schoolIssue: CommunityCategoryUi._(
      '🏫',
      'School issue',
      'مشكلة في المدرسة',
      'Problème scolaire',
      'Problema escolar',
    ),
    CommunityPostCategory.suggestion: CommunityCategoryUi._(
      '💡',
      'Suggestion',
      'اقتراح',
      'Suggestion',
      'Sugerencia',
    ),
    CommunityPostCategory.question: CommunityCategoryUi._(
      '❓',
      'Question',
      'سؤال',
      'Question',
      'Pregunta',
    ),
    CommunityPostCategory.complaint: CommunityCategoryUi._(
      '🚨',
      'Complaint',
      'شكوى',
      'Plainte',
      'Queja',
    ),
    CommunityPostCategory.feedback: CommunityCategoryUi._(
      '⭐',
      'Feedback',
      'تقييم',
      'Avis',
      'Comentario',
    ),
    CommunityPostCategory.other: CommunityCategoryUi._(
      '📌',
      'Other',
      'أخرى',
      'Autre',
      'Otro',
    ),
  };

  static CommunityCategoryUi of(CommunityPostCategory category) =>
      _byCategory[category]!;
}

/// "3m ago" / "منذ 3 دقايق" — deliberately dependency-free (no `timeago`
/// package) for a feature this small; each app that needs it keeps its own
/// copy rather than adding a new shared dependency for one label.
String communityRelativeTime(BuildContext context, DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) {
    return const S(
      'Just now',
      'الآن',
      fr: "À l'instant",
      es: 'Justo ahora',
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
    fr: 'il y a ${weeks}sem',
    es: 'hace ${weeks}sem',
  ).of(context);
}
