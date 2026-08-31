import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../../../widgets/parent_ui.dart';
import '../data/parent_requests_repository.dart';
import 'contact_school_page.dart';
import 'parent_thread_page.dart';

/// A parent's own conversations with the school — each one a real,
/// continuing thread (see [ParentThreadPage]), not a one-shot message.
class ParentRequestsPage extends StatelessWidget {
  const ParentRequestsPage({super.key, required this.user});

  final AppUser user;

  void _openNewMessage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ContactSchoolPage(user: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          const S('Messages to school', 'رسايل للمدرسة').of(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewMessage(context),
        icon: const Icon(Icons.edit_outlined),
        label: Text(const S('New message', 'رسالة جديدة').of(context)),
      ),
      body: StreamBuilder<List<ParentRequest>>(
        stream: ParentRequestsRepository().watchMyRequests(
          schoolId: user.schoolId,
          parentUid: user.uid,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: const [
                _ThreadCardSkeleton(),
                _ThreadCardSkeleton(),
                _ThreadCardSkeleton(),
              ],
            );
          }
          if (snapshot.hasError) {
            return ErrorStateView(
              message: const S(
                "Couldn't load your messages — check your connection and "
                    'try again.',
                'معرفناش نحمّل رسايلك — اتأكد من الاتصال وجرب تاني.',
              ).of(context),
            );
          }

          final requests = snapshot.data ?? const <ParentRequest>[];
          if (requests.isEmpty) {
            return EmptyStateView(
              icon: Icons.forum_outlined,
              title: const S(
                'No messages yet',
                'مفيش رسايل لسه',
              ).of(context),
              message: const S(
                'Send your school a message — about a pickup change, a '
                    "question about a trip, anything the driver needs to "
                    'know.',
                'ابعت لمدرستك رسالة — تغيير في الاستلام، سؤال عن رحلة، أي '
                    'حاجة لازم السواق يعرفها.',
              ).of(context),
              actionLabel: const S(
                'Write your first message',
                'اكتب أول رسالة',
              ).of(context),
              onAction: () => _openNewMessage(context),
            );
          }

          final unreadCount = requests.where((r) => r.unreadByParent).length;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              96,
            ),
            itemCount: requests.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _ListHeader(unreadCount: unreadCount);
              final request = requests[index - 1];
              return _ThreadCard(
                request: request,
                onTap: () => Navigator.push(
                  context,
                  appFadeThroughRoute(
                    ParentThreadPage(user: user, request: request),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.unreadCount});

  /// How many threads the school has replied to that this parent hasn't
  /// opened yet — the real `unreadByParent` flag the Cloud Function sets, not
  /// a count of messages.
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: const S('Your conversations', 'محادثاتك').of(context),
          subtitle: const S(
            'With the school office. They pass anything the driver needs '
                'on to them.',
            'مع إدارة المدرسة. وهم بيبلغوا السواق باللي يهمه.',
          ).of(context),
          trailing: unreadCount == 0
              ? null
              : StatusBadge(
                  label: unreadCount == 1
                      ? const S('1 new reply', 'رد جديد').of(context)
                      : S(
                          '$unreadCount new replies',
                          '$unreadCount ردود جديدة',
                        ).of(context),
                  tone: StatusTone.info,
                ),
        ),
        const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.request, required this.onTap});

  final ParentRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final lastActivity = request.lastMessageAt ?? request.createdAt;
    final unread = request.unreadByParent;
    final accent = theme.colorScheme.primary;
    final subject = request.subject.isEmpty
        ? const S('General question', 'سؤال عام').of(context)
        : request.subject;
    final studentName = request.studentName;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: unread ? colors.info.withValues(alpha: 0.06) : colors.surface,
        clipBehavior: Clip.antiAlias,
        // Material asserts that `shape` and `borderRadius` are never both
        // set — the rounded border lives on the shape alone.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: unread ? colors.info.withValues(alpha: 0.35) : colors.border,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A thread about one child is anchored by that child's
                // monogram; a general question by the school glyph, since
                // there's no person to name.
                studentName == null || studentName.isEmpty
                    ? Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.school_outlined,
                          size: 20,
                          color: accent,
                        ),
                      )
                    : InitialAvatar(name: studentName, color: accent),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              subject,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: unread
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            compactTimestamp(context, lastActivity),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: unread ? colors.info : colors.textMuted,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        request.lastMessagePreview ?? request.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: unread
                              ? colors.textPrimary
                              : colors.textSecondary,
                          fontWeight: unread ? FontWeight.w600 : null,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (unread)
                            StatusBadge(
                              label: const S(
                                'New reply',
                                'رد جديد',
                              ).of(context),
                              tone: StatusTone.info,
                            )
                          else
                            StatusBadge(
                              label: _statusLabel(request.status).of(context),
                              tone: _statusTone(request.status),
                            ),
                          if (studentName != null && studentName.isNotEmpty)
                            _ChildChip(name: studentName),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Names the child a thread is about, from the `studentName` the request was
/// created with — never inferred.
class _ChildChip extends StatelessWidget {
  const _ChildChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.child_care_outlined, size: 13, color: colors.textMuted),
          const SizedBox(width: 5),
          Text(
            name,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A placeholder shaped like [_ThreadCard] rather than a generic list tile, so
/// the list doesn't reflow when the real threads arrive.
class _ThreadCardSkeleton extends StatelessWidget {
  const _ThreadCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSkeleton(width: 40, height: 40, borderRadius: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                AppSkeleton(width: 160, height: 14),
                SizedBox(height: AppSpacing.sm),
                AppSkeleton(height: 12),
                SizedBox(height: AppSpacing.sm),
                AppSkeleton(width: 90, height: 20, borderRadius: 999),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Deliberately describes what the school has done, not what the parent
/// should expect next — nothing in this app promises a reply, because the
/// reply channel (a phone call, a note home) lives outside it.
S _statusLabel(ParentRequestStatus status) => switch (status) {
  ParentRequestStatus.open => const S('Sent', 'اتبعتت'),
  ParentRequestStatus.read => const S('Seen by school', 'المدرسة شافتها'),
  ParentRequestStatus.closed => const S('Closed', 'اتقفلت'),
};

StatusTone _statusTone(ParentRequestStatus status) => switch (status) {
  ParentRequestStatus.open => StatusTone.info,
  ParentRequestStatus.read => StatusTone.success,
  ParentRequestStatus.closed => StatusTone.neutral,
};
