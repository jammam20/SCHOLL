import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

/// Small composition helpers shared by the parent app's message, notification,
/// child-settings, notification-preference, profile and legal screens.
///
/// These are deliberately *not* a second design language: every one of them is
/// assembled out of the shared design system's own tokens
/// ([AppSpacing]/[AppRadius]/[AppColorTokens]) and shared components, and each
/// one exists because the exact same arrangement was already being hand-copied
/// across several of those screens. Collecting them here means the tinted
/// callout on the contact form, the one in a thread header and the one above
/// the authorized-pickup list are literally the same widget instead of three
/// near-identical `Container`s that can drift apart.

/// Maps a shared [StatusTone] onto its concrete token color. The switch
/// previously lived, privately, inside the notifications inbox; every screen
/// that tones an icon or a callout needs it.
Color toneColor(AppColorTokens colors, StatusTone tone) => switch (tone) {
  StatusTone.success => colors.success,
  StatusTone.warning => colors.warning,
  StatusTone.error => colors.error,
  StatusTone.info => colors.info,
  StatusTone.emergency => colors.emergency,
  StatusTone.neutral => colors.textMuted,
};

/// A tinted explanatory callout — the "here is how this actually works" box
/// used above the contact form, at the top of a conversation, and above the
/// authorized-pickup list. [tone] drives icon and tint so an advisory note and
/// a caution never look alike.
class InfoNotice extends StatelessWidget {
  const InfoNotice({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.tone = StatusTone.info,
    this.title,
    this.dense = false,
  });

  final String message;
  final IconData icon;
  final StatusTone tone;
  final String? title;

  /// Trims the padding and drops the border for a notice that sits flush
  /// under an app bar rather than inside a scrolling body.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final accent = toneColor(colors, tone);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dense ? AppSpacing.md : AppSpacing.lg),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: dense ? null : BorderRadius.circular(AppRadius.md),
        border: dense
            ? Border(bottom: BorderSide(color: colors.border))
            : Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: dense ? 18 : 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A bordered card that stacks rows with hairline dividers between them — the
/// grouped-settings shape used on the profile, notification-preference and
/// child-settings screens. Takes the [Card] theme's border/radius as-is so a
/// group here matches a card anywhere else in the product.
class AppListCard extends StatelessWidget {
  const AppListCard({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider(height: 1));
      rows.add(children[i]);
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }
}

/// A settings/navigation row: a tinted round icon, a title, an optional
/// supporting line, and whatever belongs at the end (a chevron, a switch, a
/// badge). One row shape across profile, notification preferences and child
/// settings, instead of each screen styling its own [ListTile].
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.tone,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Accent for the leading icon. Defaults to the app's own primary seed so a
  /// neutral row never implies a status it doesn't have.
  final Color? tone;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final accent = enabled
        ? (tone ?? theme.colorScheme.primary)
        : colors.disabled;

    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md - 2),
              ),
              child: Icon(icon, size: 19, color: accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: enabled ? colors.textPrimary : colors.textMuted,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.md),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A round monogram for a person (a child, an authorized adult, the parent
/// themselves) — used wherever a name needs a visual anchor and no photo
/// exists anywhere in this product.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.color,
  });

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    final trimmed = name.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

/// A page transition that fades and lifts slightly instead of the platform's
/// default slide, at the design system's own [AppDurations.pageTransition] —
/// used for opening a conversation from the thread list, where the default
/// push made a chat feel like a separate app rather than the same list
/// expanding. Honors the platform "reduce motion" setting by falling back to
/// a plain fade.
Route<T> appFadeThroughRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: AppDurations.pageTransition,
    reverseTransitionDuration: AppDurations.stateSwitch,
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      );
      final fade = FadeTransition(opacity: curved, child: child);
      if (MediaQuery.of(context).disableAnimations) return fade;
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(curved),
        child: fade,
      );
    },
  );
}

/// Whether [date] falls on the same calendar day as [other].
bool isSameDay(DateTime date, DateTime other) =>
    date.year == other.year && date.month == other.month && date.day == other.day;

/// "Today" / "Yesterday" / "Tomorrow" where that reads better than a date,
/// otherwise a short date.
///
/// The [DateFormat] calls are deliberately locale-less, matching every other
/// date in this app: no `initializeDateFormatting` call exists anywhere in
/// this project, so asking `intl` for Arabic date symbols would throw at
/// runtime. Only the relative words are translated.
String friendlyDay(BuildContext context, DateTime date) {
  final now = DateTime.now();
  if (isSameDay(date, now)) {
    return const S('Today', 'النهاردة').of(context);
  }
  if (isSameDay(date, now.subtract(const Duration(days: 1)))) {
    return const S('Yesterday', 'إمبارح').of(context);
  }
  if (isSameDay(date, now.add(const Duration(days: 1)))) {
    return const S('Tomorrow', 'بكرة').of(context);
  }
  if (date.year == now.year) return DateFormat('EEE, d MMM').format(date);
  return DateFormat('d MMM yyyy').format(date);
}

/// A day plus a clock time — "Today · 3:40 PM", "12 Mar · 8:05 AM".
String friendlyDateTime(BuildContext context, DateTime timestamp) =>
    '${friendlyDay(context, timestamp)} · ${DateFormat.jm().format(timestamp)}';

/// A compact "when did this happen" label for a list row: a clock time for
/// today, a relative word for yesterday/tomorrow, a short date beyond that.
String compactTimestamp(BuildContext context, DateTime timestamp) {
  final now = DateTime.now();
  if (isSameDay(timestamp, now)) return DateFormat.jm().format(timestamp);
  return friendlyDay(context, timestamp);
}
