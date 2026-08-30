import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../data/parent_requests_repository.dart';
import 'contact_school_page.dart';
import 'parent_thread_page.dart';

/// A parent's own conversations with the school — each one a real,
/// continuing thread (see [ParentThreadPage]), not a one-shot message.
class ParentRequestsPage extends StatelessWidget {
  const ParentRequestsPage({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          const S('Messages to school', 'رسايل للمدرسة').of(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ContactSchoolPage(user: user)),
        ),
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
                AppSkeletonListTile(),
                AppSkeletonListTile(),
                AppSkeletonListTile(),
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
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              88,
            ),
            itemCount: requests.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return SectionHeader(
                  title: const S('Your conversations', 'محادثاتك').of(context),
                  subtitle: const S(
                    'With the school office. They pass anything the '
                        'driver needs on to them.',
                    'مع إدارة المدرسة. وهم بيبلغوا السواق باللي يهمه.',
                  ).of(context),
                );
              }
              final request = requests[index - 1];
              return _ThreadCard(
                request: request,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ParentThreadPage(user: user, request: request),
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

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (unread)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors.info,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      request.subject.isEmpty
                          ? const S('General question', 'سؤال عام').of(context)
                          : request.subject,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  StatusBadge(
                    label: _statusLabel(request.status).of(context),
                    tone: _statusTone(request.status),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                request.lastMessagePreview ?? request.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: unread ? colors.textPrimary : colors.textSecondary,
                  fontWeight: unread ? FontWeight.w600 : null,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${DateFormat.MMMd().format(lastActivity)} · '
                '${DateFormat.jm().format(lastActivity)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
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
