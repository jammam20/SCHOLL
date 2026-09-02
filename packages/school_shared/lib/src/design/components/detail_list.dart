import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';
import 'status_badge.dart';

/// Small composition helpers for a detail/profile screen — a grouped card
/// of rows, a tinted explanatory callout, and a round monogram avatar.
///
/// Promoted here from the parent app's `widgets/parent_ui.dart` (where the
/// exact same three widgets were first proven out across its messaging,
/// notification, child-settings and profile screens) so the admin app's
/// student/parent/driver detail views can reuse them too instead of
/// hand-rolling a second copy of the same card/row/avatar shapes.

/// A tinted explanatory callout — "here is how this actually works", or a
/// caution — with [tone] driving icon and tint so the two never look alike.
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

/// A bordered card that stacks rows with hairline dividers between them —
/// the grouped-detail shape for a profile/settings screen. Takes the
/// [Card] theme's border/radius as-is so a group here matches a card
/// anywhere else in the product.
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

/// A settings/detail row: a tinted round icon, a title, an optional
/// supporting line, and whatever belongs at the end (a chevron, a switch, a
/// badge). One row shape for a profile/detail screen anywhere in the
/// product, instead of each screen styling its own [ListTile].
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

  /// Accent for the leading icon. Defaults to the app's own primary seed so
  /// a neutral row never implies a status it doesn't have.
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

/// A round monogram for a person (a student, a driver, a parent) — used
/// wherever a name needs a visual anchor and no photo exists.
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
