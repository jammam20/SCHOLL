import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Primary/secondary/destructive buttons built on the existing
/// Filled/Outlined button themes, with a consistent in-place loading
/// spinner instead of each screen hand-rolling its own. See
/// `design-system/MASTER.md` §8.
class AppButton extends StatelessWidget {
  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  }) : _variant = _Variant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  }) : _variant = _Variant.secondary;

  const AppButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  }) : _variant = _Variant.destructive;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final _Variant _variant;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final effectiveOnPressed = loading ? null : onPressed;
    final child = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: _variant == _Variant.secondary
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              // Flexible + ellipsis rather than a bare Text: this button is
              // routinely squeezed into a narrow Expanded slot (two buttons
              // side by side on a small phone, a longer Arabic label than
              // its English counterpart) — without this, a label that
              // doesn't fit throws a RenderFlex overflow instead of
              // truncating gracefully.
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          );

    switch (_variant) {
      case _Variant.primary:
        return FilledButton(onPressed: effectiveOnPressed, child: child);
      case _Variant.secondary:
        return OutlinedButton(onPressed: effectiveOnPressed, child: child);
      case _Variant.destructive:
        return FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colors.error),
          onPressed: effectiveOnPressed,
          child: child,
        );
    }
  }
}

enum _Variant { primary, secondary, destructive }
