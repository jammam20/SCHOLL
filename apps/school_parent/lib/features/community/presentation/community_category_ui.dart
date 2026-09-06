import 'package:flutter/widgets.dart';
import 'package:school_shared/school_shared.dart';

/// The emoji + bilingual label shown for each [CommunityPostCategory] —
/// kept as one small lookup so the composer, the feed chip, and the filter
/// row can never drift into showing three different labels for the same
/// category.
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

/// "3m ago" / "منذ 3 دقايق" — deliberately dependency-free (no `timeago`
/// package) for a feature this small; each app that needs it keeps its own
/// copy rather than adding a new shared dependency for one label.
String communityRelativeTime(BuildContext context, DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) {
    return const S('Just now', 'الآن').of(context);
  }
  if (diff.inMinutes < 60) {
    return S(
      '${diff.inMinutes}m ago',
      'منذ ${diff.inMinutes} د',
    ).of(context);
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
