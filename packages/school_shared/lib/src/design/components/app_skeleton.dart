import 'package:flutter/material.dart';

import '../app_theme.dart';

/// A shimmering placeholder block for list/dashboard loading states —
/// used instead of a bare spinner wherever the eventual content has a
/// predictable shape, so the loading state doesn't jump/reflow when the
/// real content arrives. See `design-system/MASTER.md` §9.
///
/// Respects `MediaQuery.disableAnimations` by rendering a static tint
/// instead of animating, per `design-system/MASTER.md` §10/§12.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.appColors.border;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    Widget block(double opacity) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: base.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
    );

    if (reduceMotion) return block(0.7);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => block(0.5 + _controller.value * 0.35),
    );
  }
}

/// A row of [AppSkeleton] blocks shaped like a typical list tile — leading
/// avatar, two lines of text.
class AppSkeletonListTile extends StatelessWidget {
  const AppSkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const AppSkeleton(width: 40, height: 40, borderRadius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                AppSkeleton(width: 140, height: 14),
                SizedBox(height: 8),
                AppSkeleton(width: 90, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
