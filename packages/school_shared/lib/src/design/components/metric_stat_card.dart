import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

/// A number with a label and an optional trend/icon — the stat-card shape
/// already used ad-hoc in the admin app's analytics tab, formalized here
/// so every dashboard number across the four apps looks the same. See
/// `design-system/MASTER.md` §8.
class MetricStatCard extends StatelessWidget {
  const MetricStatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.tone,
  });

  final String label;
  final String value;
  final IconData? icon;

  /// Optional accent color for [icon]; defaults to the current theme's
  /// primary seed so a plain metric doesn't imply a status meaning it
  /// doesn't have.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final accent = tone ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
