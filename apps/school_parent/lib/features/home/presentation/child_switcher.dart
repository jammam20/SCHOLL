import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import 'child_avatar.dart';

/// The focus control for the home tab: "All children" plus one pill per
/// child, each carrying that child's own avatar so the row is scannable by
/// color before it's read.
///
/// "All children" stays the default and is always the first option: for a
/// parent of two, seeing both at once is genuinely the better view — it's
/// the whole question they opened the app to answer. Focusing one child
/// earns its place when there are three or four, or when one bus is the
/// only thing that matters right now, so it's offered rather than imposed.
///
/// Horizontally scrollable rather than wrapped, so a parent of five gets
/// the same one-line layout as a parent of two, and it never pushes the
/// actual status content below the fold.
class ChildSwitcher extends StatelessWidget {
  const ChildSwitcher({
    super.key,
    required this.students,
    required this.selectedStudentId,
    required this.onSelected,
  });

  final List<Student> students;

  /// Null means "All children".
  final String? selectedStudentId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          _SwitcherPill(
            selected: selectedStudentId == null,
            onTap: () => onSelected(null),
            leading: _AllChildrenGlyph(
              count: students.length,
              selected: selectedStudentId == null,
            ),
            label: const S('All children', 'كل الأبناء').of(context),
          ),
          for (final student in students)
            _SwitcherPill(
              selected: selectedStudentId == student.id,
              onTap: () => onSelected(student.id),
              leading: ChildAvatar(student: student, size: 28),
              label: student.name,
            ),
        ],
      ),
    );
  }
}

class _SwitcherPill extends StatelessWidget {
  const _SwitcherPill({
    required this.selected,
    required this.onTap,
    required this.leading,
    required this.label,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget leading;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final primary = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
      child: Center(
        child: Material(
          color: selected
              ? primary.withValues(alpha: 0.12)
              : colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: selected ? primary : colors.border,
                  width: selected ? 1.6 : 1,
                ),
              ),
              padding: const EdgeInsetsDirectional.only(
                start: 6,
                end: AppSpacing.md,
                top: 6,
                bottom: 6,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  leading,
                  const SizedBox(width: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 132),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: selected ? primary : colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "all children" leading glyph — the real number of linked children
/// in a circle, so the option says how much it's actually covering.
class _AllChildrenGlyph extends StatelessWidget {
  const _AllChildrenGlyph({required this.count, required this.selected});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final primary = Theme.of(context).colorScheme.primary;
    final color = selected ? primary : colors.textMuted;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
