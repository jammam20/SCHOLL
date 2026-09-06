import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../../messages/data/parent_messages_repository.dart';
import '../../messages/presentation/admin_thread_page.dart';
import '../../parents/presentation/parent_detail_page.dart';
import '../data/community_admin_repository.dart';
import 'community_category_ui.dart';

/// The admin's full view of one community post (Feature: Parent Community)
/// — real author identity, every comment, every report, and the
/// moderation/contact actions the parent-facing [PostDetailPage] never
/// exposes. Every identity shown here comes from
/// [CommunityAdminRepository.resolveAuthor]/`resolveDisplayName`, which
/// only resolve because firestore.rules grants *this role* — not a
/// parent — read access to the `authors` subcollection.
class CommunityPostAdminDetailPage extends StatefulWidget {
  const CommunityPostAdminDetailPage({
    super.key,
    required this.schoolId,
    required this.post,
  });

  final String schoolId;
  final CommunityPost post;

  @override
  State<CommunityPostAdminDetailPage> createState() =>
      _CommunityPostAdminDetailPageState();
}

class _CommunityPostAdminDetailPageState
    extends State<CommunityPostAdminDetailPage> {
  final _repository = CommunityAdminRepository();
  final _commentController = TextEditingController();
  late CommunityPost _post = widget.post;
  bool _sendingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sendingComment) return;
    setState(() => _sendingComment = true);
    try {
      await _repository.addComment(
        schoolId: widget.schoolId,
        postId: _post.id,
        content: text,
      );
      _commentController.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(
          context,
          const S("Couldn't post your reply — try again.", 'معرفناش ننشر ردك — جرب تاني.')
              .of(context),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _setStatus(CommunityPostStatus status) async {
    final confirmed = await _confirmStatusChange(status);
    if (confirmed != true || !mounted) return;
    try {
      await _repository.changeStatus(
        schoolId: widget.schoolId,
        postId: _post.id,
        status: status,
      );
      if (!mounted) return;
      setState(() {
        _post = CommunityPost(
          id: _post.id,
          schoolId: _post.schoolId,
          category: _post.category,
          content: _post.content,
          status: status,
          createdAt: _post.createdAt,
          updatedAt: DateTime.now(),
          reactionCount: _post.reactionCount,
          commentCount: _post.commentCount,
          reportCount: _post.reportCount,
        );
      });
      AppSnackbar.success(
        context,
        const S('Post updated.', 'اتحدّث المنشور.').of(context),
      );
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(
          context,
          const S("Couldn't update the post.", 'معرفناش نحدّث المنشور.').of(context),
        );
      }
    }
  }

  Future<bool?> _confirmStatusChange(CommunityPostStatus status) {
    final (title, message, destructive) = switch (status) {
      CommunityPostStatus.hidden => (
        const S('Hide this post?', 'تخفي المنشور ده؟'),
        const S(
          'Other parents will no longer see it in the community feed.',
          'باقي أولياء الأمور مش هيشوفوه في المجتمع بعد كده.',
        ),
        false,
      ),
      CommunityPostStatus.active => (
        const S('Restore this post?', 'ترجع المنشور ده؟'),
        const S(
          'It will be visible in the community feed again.',
          'هيرجع يظهر في مجتمع المدرسة تاني.',
        ),
        false,
      ),
      CommunityPostStatus.archived => (
        const S('Archive this post?', 'تؤرشف المنشور ده؟'),
        const S(
          'It will be removed from the feed but kept on record.',
          'هيتشال من الفيد بس هيفضل محفوظ.',
        ),
        false,
      ),
      CommunityPostStatus.deleted => (
        const S('Delete this post?', 'تحذف المنشور ده؟'),
        const S(
          'It will be removed from the feed. This can be reviewed later in '
              'the audit trail.',
          'هيتشال من الفيد. تقدر تراجعه بعدين في سجل التتبع.',
        ),
        true,
      ),
    };
    return showAppConfirmDialog(
      context,
      title: title.of(context),
      message: message.of(context),
      confirmLabel: const S('Confirm', 'تأكيد').of(context),
      destructive: destructive,
    );
  }

  Future<void> _openProfile(String authorUid) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParentDetailPage(schoolId: widget.schoolId, uid: authorUid),
      ),
    );
  }

  Future<void> _messageParent(String authorUid) async {
    final repository = ParentMessagesRepository();

    // Reuse the parent's existing open thread when there is one — without
    // this check, clicking "Message parent" again (from this post or
    // another one by the same parent) created a brand-new thread every
    // time, leaving the admin inbox with duplicate conversations for the
    // same parent instead of one continuing one.
    ParentRequest? existing;
    try {
      existing = await repository.findOpenThreadWithParent(
        schoolId: widget.schoolId,
        parentUid: authorUid,
      );
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(
          context,
          const S("Couldn't open the conversation.", 'معرفناش نفتح المحادثة.').of(context),
        );
      }
      return;
    }
    if (existing != null) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminThreadPage(schoolId: widget.schoolId, request: existing!),
        ),
      );
      return;
    }

    if (!mounted) return;
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      // A plain AlertDialog never rebuilds on its own when the controller's
      // text changes — without this StatefulBuilder, the Send button's
      // enabled state is frozen from the very first (empty) build and stays
      // disabled no matter what gets typed.
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(const S('Message parent', 'راسل ولي الأمر').of(context)),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 5,
            autofocus: true,
            onChanged: (_) => setDialogState(() {}),
            decoration: InputDecoration(
              hintText: const S(
                'About their community post…',
                'بخصوص منشورهم في المجتمع…',
              ).of(context),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(const S('Cancel', 'إلغاء').of(context)),
            ),
            FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, controller.text.trim()),
              child: Text(const S('Send', 'إرسال').of(context)),
            ),
          ],
        ),
      ),
    );
    if (message == null || message.isEmpty || !mounted) return;
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) return;
    try {
      final request = await repository.openThreadWithParent(
        schoolId: widget.schoolId,
        parentUid: authorUid,
        adminUid: adminUid,
        subject: const S(
          'About your community post',
          'بخصوص منشورك في المجتمع',
        ).of(context),
        message: message,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminThreadPage(schoolId: widget.schoolId, request: request),
        ),
      );
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(
          context,
          const S("Couldn't start the conversation.", 'معرفناش نبدأ المحادثة.')
              .of(context),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final category = CommunityCategoryUi.of(_post.category);

    return Scaffold(
      appBar: AppBar(
        title: Text(const S('Post', 'المنشور').of(context)),
        actions: [
          PopupMenuButton<CommunityPostStatus>(
            onSelected: _setStatus,
            itemBuilder: (context) => [
              if (_post.status != CommunityPostStatus.active)
                PopupMenuItem(
                  value: CommunityPostStatus.active,
                  child: Text(const S('Restore', 'استرجاع').of(context)),
                ),
              if (_post.status != CommunityPostStatus.hidden)
                PopupMenuItem(
                  value: CommunityPostStatus.hidden,
                  child: Text(const S('Hide', 'إخفاء').of(context)),
                ),
              if (_post.status != CommunityPostStatus.archived)
                PopupMenuItem(
                  value: CommunityPostStatus.archived,
                  child: Text(const S('Archive', 'أرشفة').of(context)),
                ),
              if (_post.status != CommunityPostStatus.deleted)
                PopupMenuItem(
                  value: CommunityPostStatus.deleted,
                  child: Text(
                    const S('Delete', 'حذف').of(context),
                    style: TextStyle(color: colors.error),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
          FutureBuilder<CommunityPostAuthor?>(
            future: _repository.resolveAuthor(
              schoolId: widget.schoolId,
              postId: _post.id,
            ),
            builder: (context, authorSnapshot) {
              final author = authorSnapshot.data;
              if (author == null) {
                return const AppSkeletonListTile();
              }
              return FutureBuilder<String?>(
                future: _repository.resolveDisplayName(
                  schoolId: widget.schoolId,
                  uid: author.authorUid,
                ),
                builder: (context, nameSnapshot) {
                  final name = nameSnapshot.data ?? author.authorUid;
                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: colors.surface,
                          foregroundColor: colors.textSecondary,
                          child: const Icon(Icons.person),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: theme.textTheme.titleSmall),
                              Text(
                                const S('Parent', 'ولي أمر').of(context),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: const S('View profile', 'عرض الملف').of(context),
                          icon: const Icon(Icons.badge_outlined),
                          onPressed: () => _openProfile(author.authorUid),
                        ),
                        IconButton(
                          tooltip: const S('Message parent', 'راسل ولي الأمر').of(
                            context,
                          ),
                          icon: const Icon(Icons.chat_bubble_outline),
                          onPressed: () => _messageParent(author.authorUid),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                '${category.emoji} ${category.label(context)}',
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              StatusBadge(
                label: communityStatusLabel(context, _post.status),
                tone: switch (_post.status) {
                  CommunityPostStatus.active => StatusTone.success,
                  CommunityPostStatus.hidden => StatusTone.warning,
                  CommunityPostStatus.archived => StatusTone.neutral,
                  CommunityPostStatus.deleted => StatusTone.error,
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(_post.content, style: theme.textTheme.bodyLarge),
          const Divider(height: AppSpacing.xl2),
          Text(
            const S('Comments', 'التعليقات').of(context),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          StreamBuilder<List<CommunityComment>>(
            stream: _repository.watchComments(
              schoolId: widget.schoolId,
              postId: _post.id,
            ),
            builder: (context, snapshot) {
              final comments = snapshot.data ?? const <CommunityComment>[];
              if (comments.isEmpty) {
                return Text(
                  const S('No comments yet.', 'لسه مفيش تعليقات.').of(context),
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                );
              }
              return Column(
                children: [
                  for (final comment in comments)
                    _AdminCommentTile(
                      key: ValueKey(comment.id),
                      schoolId: widget.schoolId,
                      postId: _post.id,
                      comment: comment,
                      repository: _repository,
                      onOpenProfile: _openProfile,
                      onMessage: _messageParent,
                    ),
                ],
              );
            },
          ),
          const Divider(height: AppSpacing.xl2),
          Text(
            const S('Reports', 'البلاغات').of(context),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          StreamBuilder<List<CommunityReport>>(
            stream: _repository.watchReports(schoolId: widget.schoolId, postId: _post.id),
            builder: (context, snapshot) {
              final reports = snapshot.data ?? const <CommunityReport>[];
              if (reports.isEmpty) {
                return Text(
                  const S('No reports on this post.', 'مفيش بلاغات على المنشور ده.')
                      .of(context),
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                );
              }
              return Column(
                children: [
                  for (final report in reports)
                    _ReportTile(
                      key: ValueKey(report.id),
                      schoolId: widget.schoolId,
                      report: report,
                      repository: _repository,
                    ),
                ],
              );
            },
          ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      minLines: 1,
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: const S(
                          'Reply as your school…',
                          'رد باسم المدرسة…',
                        ).of(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _sendingComment
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send_rounded),
                          onPressed: _commentController.text.trim().isEmpty
                              ? null
                              : _sendComment,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _reportReasonLabel(BuildContext context, CommunityReportReason reason) {
  return switch (reason) {
    CommunityReportReason.inappropriate => const S(
      'Inappropriate content',
      'محتوى غير مناسب',
    ).of(context),
    CommunityReportReason.abuse => const S('Abuse', 'إساءة').of(context),
    CommunityReportReason.misleading => const S(
      'Misleading information',
      'معلومات مضللة',
    ).of(context),
    CommunityReportReason.spam => const S('Spam', 'سبام').of(context),
    CommunityReportReason.other => const S('Other', 'أخرى').of(context),
  };
}

class _AdminCommentTile extends StatelessWidget {
  const _AdminCommentTile({
    super.key,
    required this.schoolId,
    required this.postId,
    required this.comment,
    required this.repository,
    required this.onOpenProfile,
    required this.onMessage,
  });

  final String schoolId;
  final String postId;
  final CommunityComment comment;
  final CommunityAdminRepository repository;
  final ValueChanged<String> onOpenProfile;
  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    // An admin's own reply is a real, identified voice (see
    // CommunityComment.isAdmin's own doc comment) — there is no author to
    // resolve, and offering "View profile"/"Message parent" on the
    // school's own reply would make no sense, so it gets a distinct,
    // simpler row instead of the parent-comment one below.
    if (comment.isAdmin) {
      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school_outlined, size: 16, color: colors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  const S('School Admin', 'إدارة المدرسة').of(context),
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                Text(
                  communityRelativeTime(context, comment.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
            Text(comment.content, style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  communityRelativeTime(context, comment.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
                Text(comment.content, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          FutureBuilder<CommunityPostAuthor?>(
            future: repository.resolveAuthor(
              schoolId: schoolId,
              postId: postId,
              commentId: comment.id,
            ),
            builder: (context, snapshot) {
              final author = snapshot.data;
              return PopupMenuButton<String>(
                enabled: author != null,
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (value) {
                  if (author == null) return;
                  if (value == 'profile') onOpenProfile(author.authorUid);
                  if (value == 'message') onMessage(author.authorUid);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Text(const S('View profile', 'عرض الملف').of(context)),
                  ),
                  PopupMenuItem(
                    value: 'message',
                    child: Text(
                      const S('Message parent', 'راسل ولي الأمر').of(context),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    super.key,
    required this.schoolId,
    required this.report,
    required this.repository,
  });

  final String schoolId;
  final CommunityReport report;
  final CommunityAdminRepository repository;

  Future<void> _resolve(BuildContext context) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) return;
    try {
      await repository.resolveReport(
        schoolId: schoolId,
        postId: report.postId,
        reportId: report.id,
        adminUid: adminUid,
      );
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.error(
          context,
          const S("Couldn't mark this report resolved.", 'معرفناش نحل البلاغ ده.')
              .of(context),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final resolved = report.status == CommunityReportStatus.resolved;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _reportReasonLabel(context, report.reason),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (report.details != null && report.details!.isNotEmpty)
                  Text(report.details!, style: theme.textTheme.bodySmall),
                Text(
                  communityRelativeTime(context, report.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          if (resolved)
            StatusBadge(
              label: const S('Resolved', 'اتحل').of(context),
              tone: StatusTone.success,
            )
          else
            AppButton.secondary(
              label: const S('Mark resolved', 'اعتباره تم الحل').of(context),
              onPressed: () => _resolve(context),
            ),
        ],
      ),
    );
  }
}
