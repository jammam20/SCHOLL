import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../data/community_repository.dart';
import 'community_category_ui.dart';
import 'report_post_dialog.dart';

const _maxCommentLength = 500;

/// One post, its comments, and the reaction/report actions (Feature: Parent
/// Community). Every comment shown here carries the exact same "ولي أمر"
/// anonymous identity as the post itself — see [CommunityComment], which
/// never carries an author field either.
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.user, required this.post});

  final AppUser user;
  final CommunityPost post;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _repository = CommunityRepository();
  final _commentController = TextEditingController();
  bool _sendingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || text.length > _maxCommentLength || _sendingComment) {
      return;
    }
    setState(() => _sendingComment = true);
    try {
      await _repository.addComment(
        schoolId: widget.user.schoolId,
        postId: widget.post.id,
        parentUid: widget.user.uid,
        content: text,
      );
      _commentController.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(
          context,
          const S(
            "Couldn't post your comment — try again.",
            'معرفناش ننشر التعليق — جرب تاني.',
          ).of(context),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _report() async {
    final result = await showReportPostDialog(context);
    if (result == null || !mounted) return;
    try {
      await _repository.reportPost(
        schoolId: widget.user.schoolId,
        postId: widget.post.id,
        reporterUid: widget.user.uid,
        reason: result.reason,
        details: result.details,
      );
      if (mounted) {
        AppSnackbar.success(
          context,
          const S(
            'Thanks — your school will review this.',
            'شكراً — مدرستك هتراجع البلاغ ده.',
          ).of(context),
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(
          context,
          const S("Couldn't send the report — try again.", 'معرفناش نبعت البلاغ — جرب تاني.')
              .of(context),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final category = CommunityCategoryUi.of(widget.post.category);

    return Scaffold(
      appBar: AppBar(
        title: Text(const S('Post', 'المنشور').of(context)),
        actions: [
          IconButton(
            tooltip: const S('Report', 'إبلاغ').of(context),
            icon: const Icon(Icons.flag_outlined),
            onPressed: _report,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: colors.surfaceElevated,
                      foregroundColor: colors.textSecondary,
                      child: const Icon(Icons.person, size: 18),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            const S('Parent', 'ولي أمر').of(context),
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            communityRelativeTime(
                              context,
                              widget.post.createdAt,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${category.emoji} ${category.label(context)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(widget.post.content, style: theme.textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.lg),
                _ReactionRow(
                  schoolId: widget.user.schoolId,
                  postId: widget.post.id,
                  uid: widget.user.uid,
                  baseCount: widget.post.reactionCount,
                ),
                const Divider(height: AppSpacing.xl2),
                Text(
                  const S('Comments', 'التعليقات').of(context),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                StreamBuilder<List<CommunityComment>>(
                  stream: _repository.watchComments(
                    schoolId: widget.user.schoolId,
                    postId: widget.post.id,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        child: AppSkeletonListTile(),
                      );
                    }
                    if (snapshot.hasError) {
                      return ErrorStateView(
                        compact: true,
                        message: const S(
                          "Couldn't load comments.",
                          'معرفناش نحمّل التعليقات.',
                        ).of(context),
                      );
                    }
                    final comments = snapshot.data ?? const [];
                    if (comments.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        child: Text(
                          const S(
                            'No comments yet — be the first to reply.',
                            'لسه مفيش تعليقات — كن أول واحد يرد.',
                          ).of(context),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final comment in comments)
                          Padding(
                            key: ValueKey(comment.id),
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 13,
                                  backgroundColor: comment.isAdmin
                                      ? Theme.of(context).colorScheme.primary
                                      : colors.surfaceElevated,
                                  foregroundColor: comment.isAdmin
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : colors.textSecondary,
                                  child: Icon(
                                    comment.isAdmin
                                        ? Icons.school_outlined
                                        : Icons.person,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            comment.isAdmin
                                                ? const S(
                                                    'School Admin',
                                                    'إدارة المدرسة',
                                                  ).of(context)
                                                : const S(
                                                    'Parent',
                                                    'ولي أمر',
                                                  ).of(context),
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            communityRelativeTime(
                                              context,
                                              comment.createdAt,
                                            ),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colors.textMuted,
                                                ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        comment.content,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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
                          'Write a comment…',
                          'اكتب تعليق…',
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
                          onPressed:
                              _commentController.text.trim().isEmpty ||
                                  _commentController.text.trim().length >
                                      _maxCommentLength
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

/// The 👍 toggle — reads the caller's own reaction doc for its current
/// state, so the button never disagrees with what tapping it would do.
class _ReactionRow extends StatelessWidget {
  const _ReactionRow({
    required this.schoolId,
    required this.postId,
    required this.uid,
    required this.baseCount,
  });

  final String schoolId;
  final String postId;
  final String uid;
  final int baseCount;

  @override
  Widget build(BuildContext context) {
    final repository = CommunityRepository();
    return StreamBuilder<bool>(
      stream: repository.watchMyReaction(
        schoolId: schoolId,
        postId: postId,
        uid: uid,
      ),
      builder: (context, snapshot) {
        final reacted = snapshot.data ?? false;
        return OutlinedButton.icon(
          onPressed: () => repository.toggleReaction(
            schoolId: schoolId,
            postId: postId,
            uid: uid,
            currentlyReacted: reacted,
          ),
          icon: Icon(
            reacted ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
            size: 18,
            color: reacted ? Theme.of(context).colorScheme.primary : null,
          ),
          label: Text(const S('Helpful', 'مفيد').of(context)),
        );
      },
    );
  }
}
