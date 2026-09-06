import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../../widgets/parent_ui.dart';
import '../data/notifications_repository.dart';
import 'notification_type_visuals.dart';

/// The durable history behind the pushes this app already sends: every
/// trip/emergency/boarding/school-message event a parent was notified
/// about, readable after the push banner is long gone.
///
/// Nothing is generated here — each row is a document a Cloud Function
/// wrote at `users/{uid}/notifications/{id}` at the moment it sent the
/// matching FCM push. Tapping a row marks it read, the one field a client
/// is allowed to touch.
class NotificationsInboxPage extends StatefulWidget {
  const NotificationsInboxPage({super.key, required this.uid});

  final String uid;

  @override
  State<NotificationsInboxPage> createState() => _NotificationsInboxPageState();
}

class _NotificationsInboxPageState extends State<NotificationsInboxPage> {
  final _repository = NotificationsRepository();

  Future<void> _markRead(AppNotification notification) async {
    if (notification.read) return;
    try {
      await _repository.markRead(widget.uid, notification.id);
    } catch (_) {
      // The list is a live stream, so a failed write simply means the row
      // stays unread — but say so rather than leaving the tap looking
      // like it did nothing.
      if (!mounted) return;
      AppSnackbar.error(
        context,
        const S(
          "Couldn't mark that as read — try again.",
          'معرفناش نعلّمه كمقروء — جرب تاني.',
        ).of(context),
      );
    }
  }

  Future<void> _markAllRead(List<AppNotification> unread) async {
    try {
      await _repository.markAllRead(widget.uid, unread.map((n) => n.id));
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(
        context,
        const S(
          "Couldn't mark those as read — try again.",
          'معرفناش نعلّمهم كمقروءين — جرب تاني.',
        ).of(context),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: _repository.watchNotifications(widget.uid),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? const <AppNotification>[];
        final unread = notifications.where((n) => !n.read).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(const S('Notifications', 'الإشعارات').of(context)),
            actions: [
              if (unread.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: AppSpacing.sm,
                  ),
                  child: TextButton.icon(
                    onPressed: () => _markAllRead(unread),
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: Text(
                      const S('Mark all read', 'علّم الكل كمقروء').of(context),
                    ),
                  ),
                ),
            ],
          ),
          body: _buildBody(context, snapshot, notifications, unread.length),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<List<AppNotification>> snapshot,
    List<AppNotification> notifications,
    int unreadCount,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          AppSkeletonListTile(),
          AppSkeletonListTile(),
          AppSkeletonListTile(),
          AppSkeletonListTile(),
        ],
      );
    }

    if (snapshot.hasError) {
      return ErrorStateView(
        message: const S(
          "Couldn't load your notifications — check your connection and "
              'try again.',
          'معرفناش نحمّل إشعاراتك — اتأكد من الاتصال وجرب تاني.',
        ).of(context),
      );
    }

    if (notifications.isEmpty) {
      return EmptyStateView(
        icon: Icons.notifications_none,
        title: const S('No notifications yet', 'مفيش إشعارات لسه').of(context),
        message: const S(
          "Trip updates and school messages will show up here as they "
              'happen.',
          'تحديثات الرحلة ورسايل المدرسة هتظهر هنا أول ما تحصل.',
        ).of(context),
      );
    }

    // The stream is already newest-first, so walking it in order and
    // emitting a header whenever the calendar day changes groups it without
    // re-sorting or bucketing anything.
    final rows = <Widget>[];
    if (unreadCount > 0) {
      rows.add(_UnreadSummary(count: unreadCount));
    }
    for (var i = 0; i < notifications.length; i++) {
      final notification = notifications[i];
      final previous = i == 0 ? null : notifications[i - 1];
      if (previous == null ||
          !isSameDay(previous.createdAt, notification.createdAt)) {
        rows.add(_DayHeading(date: notification.createdAt));
      }
      rows.add(
        _NotificationCard(
          notification: notification,
          onTap: () => _markRead(notification),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl3,
      ),
      children: rows,
    );
  }
}

/// How many entries are still unread — the same count the app bar's badge is
/// driven by, restated where the list itself begins.
class _UnreadSummary extends StatelessWidget {
  const _UnreadSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            Icons.mark_email_unread_outlined,
            size: 18,
            color: colors.info,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            count == 1
                ? const S('1 unread', 'واحد مش مقروء').of(context)
                : S('$count unread', '$count مش مقروءين').of(context),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.info,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        friendlyDay(context, date),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.appColors.textMuted,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final tone = notificationTypeTone(notification.type);
    final accent = toneColor(colors, tone);
    final isUnread = !notification.read;
    final isEmergency = tone == StatusTone.emergency;

    final iconBadge = Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md - 2),
      ),
      child: Icon(notificationTypeIcon(notification.type), color: accent, size: 19),
    );

    final titleRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            notification.title,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.textPrimary,
              fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        if (isUnread) ...[
          const SizedBox(width: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
          ),
        ],
      ],
    );

    final metaRow = Row(
      children: [
        StatusBadge(
          label: notificationTypeLabel(notification.type).of(context),
          tone: tone,
        ),
        const Spacer(),
        Text(
          DateFormat.jm().format(notification.createdAt),
          style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
        ),
      ],
    );

    final textColumn = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleRow,
          const SizedBox(height: 3),
          Text(
            notification.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          metaRow,
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        // Unread rows carry a faint tint of their own tone as well as the
        // dot and the heavier title — one cue is easy to miss on a phone
        // held at arm's length. An emergency keeps its tint even once read:
        // it stays the most serious thing on the screen.
        color: isUnread || isEmergency
            ? accent.withValues(alpha: isEmergency ? 0.10 : 0.06)
            : colors.surface,
        clipBehavior: Clip.antiAlias,
        // Material asserts that `shape` and `borderRadius` are never both
        // set — the rounded border lives on the shape alone.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: isEmergency
                ? accent.withValues(alpha: 0.55)
                : (isUnread ? accent.withValues(alpha: 0.32) : colors.border),
            width: isEmergency ? 1.4 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Container(
            // The accent rail used to be a sibling flex child inside an
            // IntrinsicHeight Row, stretched to match this card's content
            // height. IntrinsicHeight computes that height itself (from
            // computeMinIntrinsicHeight), which can land a hair short of
            // what the body text's `height: 1.45` line-height multiplier
            // actually lays out to — a 1px rounding gap that showed up as a
            // real, 100%-reproducible "RenderFlex overflowed by 1.00
            // pixels" on every notification. A left border paints the same
            // full-height accent rail without computing an intrinsic height
            // at all, so there's nothing left to round.
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: accent, width: isEmergency ? 4 : 3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  iconBadge,
                  const SizedBox(width: AppSpacing.md),
                  textColumn,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// The per-type icon/tone/label mapping lives in
// notification_type_visuals.dart, so it can be tested directly against the
// set of event types functions/src/index.ts actually writes.
