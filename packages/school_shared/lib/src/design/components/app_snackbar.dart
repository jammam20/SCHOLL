import 'package:flutter/material.dart';

import '../app_theme.dart';

/// One consistent icon/color per outcome, replacing ad-hoc
/// `ScaffoldMessenger.of(context).showSnackBar(...)` calls that previously
/// varied screen to screen. See `design-system/MASTER.md` §8/§9.
class AppSnackbar {
  AppSnackbar._();

  static void success(BuildContext context, String message) =>
      _show(context, message, Icons.check_circle_rounded, context.appColors.success);

  static void error(BuildContext context, String message) =>
      _show(context, message, Icons.error_rounded, context.appColors.error);

  static void info(BuildContext context, String message) =>
      _show(context, message, Icons.info_rounded, context.appColors.info);

  static void _show(
    BuildContext context,
    String message,
    IconData icon,
    Color color,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
