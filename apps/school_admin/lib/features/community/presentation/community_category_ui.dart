import 'package:flutter/widgets.dart';
import 'package:school_shared/school_shared.dart';

/// The emoji + bilingual label shown for each [CommunityPostCategory] on
/// the admin side — a deliberate duplicate of the parent app's own copy
/// (apps don't share UI code across each other, only through
/// `school_shared`, and this lookup is display-only), kept identical so a
/// post never shows a different category label to an admin than it showed
/// to the parent who filed it.
class CommunityCategoryUi {
  const CommunityCategoryUi._(this.emoji, this.en, this.ar);

  final String emoji;
  final String en;
  final String ar;

  String label(BuildContext context) => S(en, ar).of(context);

  static const _byCategory = {
    CommunityPostCategory.busIssue: CommunityCategoryUi._(
      '🚌',
      'Bus issue',
      'مشكلة في الأتوبيس',
    ),
    CommunityPostCategory.pickupPoint: CommunityCategoryUi._(
      '📍',
      'Pickup point issue',
      'مشكلة في نقطة الاستلام',
    ),
    CommunityPostCategory.delay: CommunityCategoryUi._('⏰', 'Delay', 'تأخير'),
    CommunityPostCategory.schoolIssue: CommunityCategoryUi._(
      '🏫',
      'School issue',
      'مشكلة في المدرسة',
    ),
    CommunityPostCategory.suggestion: CommunityCategoryUi._(
      '💡',
      'Suggestion',
      'اقتراح',
    ),
    CommunityPostCategory.question: CommunityCategoryUi._('❓', 'Question', 'سؤال'),
    CommunityPostCategory.complaint: CommunityCategoryUi._(
      '🚨',
      'Complaint',
      'شكوى',
    ),
    CommunityPostCategory.feedback: CommunityCategoryUi._(
      '⭐',
      'Feedback',
      'تقييم',
    ),
    CommunityPostCategory.other: CommunityCategoryUi._('📌', 'Other', 'أخرى'),
  };

  static CommunityCategoryUi of(CommunityPostCategory category) =>
      _byCategory[category]!;
}

/// Bilingual status label for the admin moderation UI — [CommunityPost]
/// doesn't carry one itself since only the admin app ever needs to display
/// a status word (the parent feed only ever shows `active` posts at all).
String communityStatusLabel(BuildContext context, CommunityPostStatus status) {
  return switch (status) {
    CommunityPostStatus.active => const S('Active', 'نشط').of(context),
    CommunityPostStatus.hidden => const S('Hidden', 'مخفي').of(context),
    CommunityPostStatus.archived => const S('Archived', 'مؤرشف').of(context),
    CommunityPostStatus.deleted => const S('Deleted', 'محذوف').of(context),
  };
}

/// Same relative-time formatting as the parent app's own copy — see that
/// file's doc comment for why this stays a small per-app duplicate rather
/// than a shared dependency.
String communityRelativeTime(BuildContext context, DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) {
    return const S('Just now', 'الآن').of(context);
  }
  if (diff.inMinutes < 60) {
    return S('${diff.inMinutes}m ago', 'منذ ${diff.inMinutes} د').of(context);
  }
  if (diff.inHours < 24) {
    return S('${diff.inHours}h ago', 'منذ ${diff.inHours} س').of(context);
  }
  if (diff.inDays < 7) {
    return S('${diff.inDays}d ago', 'منذ ${diff.inDays} يوم').of(context);
  }
  final weeks = diff.inDays ~/ 7;
  return S('${weeks}w ago', 'منذ $weeks أسبوع').of(context);
}
