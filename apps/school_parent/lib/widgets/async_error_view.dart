import 'package:flutter/material.dart';

import '../app/app_settings.dart';

/// A consistent "this failed to load" state for a StreamBuilder/FutureBuilder
/// that hit `snapshot.hasError` — shown instead of quietly falling through to
/// an empty-state UI, which used to make a permission-denied or network
/// error look identical to "there's genuinely nothing here yet".
class AsyncErrorView extends StatelessWidget {
  const AsyncErrorView({super.key, this.compact = false});

  /// A smaller, inline form for embedding inside a card or dialog rather
  /// than filling a whole screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final message = const S(
      "Couldn't load this — check your connection and try again.",
      'معرفناش نحمّل البيانات دي — اتأكد من الاتصال وجرب تاني.',
    ).of(context);

    if (compact) {
      return Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: colors.error),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: colors.error))),
        ],
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: colors.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
