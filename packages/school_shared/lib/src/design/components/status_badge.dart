import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

/// The semantic meaning behind a [StatusBadge]'s color — never chosen by
/// hand per screen, so "success" always looks the same everywhere it
/// appears. See `design-system/MASTER.md` §2 and §8.
enum StatusTone { success, warning, error, info, emergency, neutral }

/// The one dot+label pattern used everywhere a trip/bus/membership/
/// emergency status appears, so a parent who only opens the app during a
/// crisis still recognizes what they're looking at. Deliberately small and
/// undecorated — a colored dot and a label, nothing else.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  Color _color(AppColorTokens tokens) {
    switch (tone) {
      case StatusTone.success:
        return tokens.success;
      case StatusTone.warning:
        return tokens.warning;
      case StatusTone.error:
        return tokens.error;
      case StatusTone.info:
        return tokens.info;
      case StatusTone.emergency:
        return tokens.emergency;
      case StatusTone.neutral:
        return tokens.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context.appColors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
