import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../app_theme.dart';

/// A clear explanation and, only when a real action exists, one button to
/// take it — replacing ad-hoc empty-state `Column`s scattered per screen.
/// See `design-system/MASTER.md` §8/§9.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 20 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 32 : 40, color: colors.textMuted),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A consistent "this failed to load" state for a `StreamBuilder`/
/// `FutureBuilder` that hit `snapshot.hasError` — a shared replacement for
/// the four apps' previously near-identical `AsyncErrorView` widgets. Kept
/// under the name [ErrorStateView] with the same `compact` parameter shape
/// those widgets already used, so call sites don't need to change.
///
/// Pass [message] to surface a real, typed exception's own text (e.g.
/// `SchoolLocationException`, `TripOperationException`) instead of the
/// generic fallback — a friendlier error beats "something went wrong"
/// whenever the underlying error actually explains what happened.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    this.compact = false,
    this.message,
    this.onRetry,
  });

  final bool compact;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text =
        message ??
        const S(
          "Couldn't load this — check your connection and try again.",
          'معرفناش نحمّل البيانات دي — اتأكد من الاتصال وجرب تاني.',
          fr: 'Chargement impossible — vérifiez votre connexion et réessayez.',
          es: 'No se pudo cargar — comprueba tu conexión e inténtalo de nuevo.',
        ).of(context);

    if (compact) {
      return Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: colors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: colors.error)),
          ),
        ],
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: colors.error),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(
                  const S(
                    'Retry',
                    'إعادة المحاولة',
                    fr: 'Réessayer',
                    es: 'Reintentar',
                  ).of(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
