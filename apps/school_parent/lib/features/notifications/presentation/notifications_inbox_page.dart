import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../data/notifications_repository.dart';

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
            title: Text(
              const S('Notifications', 'الإشعارات').of(context),
            ),
            actions: [
              if (unread.isNotEmpty)
                TextButton(
                  onPressed: () => _markAllRead(unread),
                  child: Text(
                    const S('Mark all read', 'علّم الكل كمقروء').of(context),
                  ),
                ),
            ],
          ),
          body: _buildBody(context, snapshot, notifications),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<List<AppNotification>> snapshot,
    List<AppNotification> notifications,
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

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: notifications.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _NotificationTile(
          notification: notification,
          onTap: () => _markRead(notification),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final tone = _typeTone(notification.type);
    final toneColor = _toneColor(colors, tone);
    final isUnread = !notification.read;

    return ListTile(
      onTap: onTap,
      // Unread rows carry a faint tint of their own tone as well as the
      // dot and the heavier title — one cue is easy to miss on a phone
      // held at arm's length.
      tileColor: isUnread ? toneColor.withValues(alpha: 0.06) : null,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: toneColor.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(_typeIcon(notification.type), color: toneColor, size: 20),
      ),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              notification.title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: isUnread ? FontWeight.w800 : FontWeight.w500,
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
                decoration: BoxDecoration(
                  color: toneColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xs),
          Text(
            notification.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _formatTimestamp(context, notification.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Same event-type strings the Cloud Functions stamp on each entry (and on
/// the matching FCM payload's `data.type`) — see `AppNotification.type`.
/// An unrecognized type still renders, neutrally, rather than being hidden:
/// a notification a parent was pushed should never silently vanish from the
/// inbox just because this app is older than the server that wrote it.
IconData _typeIcon(String type) => switch (type) {
  'trip' => Icons.directions_bus,
  'emergency' => Icons.warning_amber_rounded,
  'student_boarded' => Icons.how_to_reg,
  'student_dropped_off' => Icons.waving_hand_outlined,
  'bus_changed' => Icons.swap_horiz,
  'route_deviation' => Icons.alt_route,
  'school_message' => Icons.campaign_outlined,
  _ => Icons.notifications_none,
};

StatusTone _typeTone(String type) => switch (type) {
  'trip' => StatusTone.info,
  'emergency' => StatusTone.emergency,
  'student_boarded' => StatusTone.success,
  'student_dropped_off' => StatusTone.success,
  'bus_changed' => StatusTone.warning,
  'route_deviation' => StatusTone.warning,
  'school_message' => StatusTone.info,
  _ => StatusTone.neutral,
};

Color _toneColor(AppColorTokens colors, StatusTone tone) => switch (tone) {
  StatusTone.success => colors.success,
  StatusTone.warning => colors.warning,
  StatusTone.error => colors.error,
  StatusTone.info => colors.info,
  StatusTone.emergency => colors.emergency,
  StatusTone.neutral => colors.textMuted,
};

String _formatTimestamp(BuildContext context, DateTime createdAt) {
  final now = DateTime.now();
  final isToday =
      createdAt.year == now.year &&
      createdAt.month == now.month &&
      createdAt.day == now.day;
  final time = DateFormat.jm().format(createdAt);
  if (isToday) {
    return S('Today $time', 'النهاردة $time').of(context);
  }
  return '${DateFormat.MMMd().format(createdAt)} · $time';
}
