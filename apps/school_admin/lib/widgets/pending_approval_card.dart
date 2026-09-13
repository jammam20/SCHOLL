import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

/// One action offered on a [PendingApprovalCard] — Approve, Suspend,
/// Reject, Accept, whatever the specific workflow needs. [destructive]
/// actions (reject/suspend) get the red confirm button and, when
/// [requiresReason] is set, a reason field the confirm dialog captures and
/// hands back through [onConfirmed].
class ApprovalAction {
  const ApprovalAction({
    required this.label,
    required this.icon,
    required this.onConfirmed,
    this.destructive = false,
    this.requiresReason = false,
    this.confirmTitle,
    this.confirmMessage,
  });

  final String label;
  final IconData icon;
  final bool destructive;
  final bool requiresReason;

  /// Shown in the confirmation dialog; falls back to a generic "Are you
  /// sure?" built from [label] when omitted.
  final String? confirmTitle;
  final String? confirmMessage;

  /// Called once the admin has confirmed — [reason] is the entered text
  /// when [requiresReason], otherwise always null. Any thrown error is
  /// caught by [PendingApprovalCard] and shown as an error snackbar; the
  /// card does not need its own try/catch.
  final Future<void> Function(String? reason) onConfirmed;
}

/// One consistent pending-item card — used for student approval, driver
/// approval, parent approval, and a parent's child-location request, so an
/// admin sees the exact same shape (icon, title, subtitle, action buttons,
/// confirm-then-audit flow) no matter which kind of request it is, instead
/// of four differently-built cards.
///
/// This intentionally does not decide *what* the actions are or what they
/// do — each call site supplies its own [ApprovalAction] list, built from
/// whichever repository method that workflow already used before this
/// component existed. Unifying the UI never means routing every workflow
/// through one new backend path; the existing security/business rules
/// behind each action are untouched.
class PendingApprovalCard extends StatefulWidget {
  const PendingApprovalCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.detail,
    required this.actions,
    this.tone = StatusTone.warning,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// An optional extra line of context (e.g. "Requested Sep 1, 3:40 PM") —
  /// kept separate from [subtitle] so a long detail line never crowds out
  /// the short status line every card shows.
  final String? detail;
  final List<ApprovalAction> actions;

  /// Tone for the leading icon badge — [StatusTone.warning] ("awaiting
  /// review") by default, since that's what every pending item already is.
  final StatusTone tone;

  /// Opens a fuller review view (e.g. a map for a location request) —
  /// optional; the card works fine with just its action buttons when the
  /// summary already says everything worth reviewing.
  final VoidCallback? onTap;

  @override
  State<PendingApprovalCard> createState() => _PendingApprovalCardState();
}

class _PendingApprovalCardState extends State<PendingApprovalCard> {
  bool _busy = false;

  Future<void> _run(ApprovalAction action) async {
    final reasonController = action.requiresReason
        ? TextEditingController()
        : null;
    final confirmed = await showAppConfirmDialog(
      context,
      title: action.confirmTitle ?? action.label,
      message: action.confirmMessage ??
          const S(
            'Are you sure?',
            'متأكد؟',
            fr: 'Êtes-vous sûr ?',
            es: '¿Estás seguro?',
          ).of(context),
      confirmLabel: action.label,
      destructive: action.destructive,
      reasonController: reasonController,
      reasonHint: action.requiresReason
          ? const S(
              'Reason (visible in the audit log)',
              'السبب (يظهر في سجل التدقيق)',
              fr: "Motif (visible dans le journal d'audit)",
              es: 'Motivo (visible en el registro de auditoría)',
            ).of(context)
          : null,
      reasonRequired: action.requiresReason,
    );
    // Deliberately not disposed here: the dialog's own TextField is still
    // mounted and mid-exit-transition when this Future resolves (showDialog
    // completes as soon as Navigator.pop is called, before the reverse
    // animation finishes), so an immediate dispose() crashes with "A
    // TextEditingController was used after being disposed" the next time
    // that still-animating TextField rebuilds. A short-lived, unowned
    // controller with no other resources is safe to just let the GC
    // collect once this closure returns.
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await action.onConfirmed(
        action.requiresReason ? reasonController?.text.trim() : null,
      );
      if (!mounted) return;
      AppSnackbar.success(
        context,
        S(
          '${action.label} — done.',
          '${action.label} — تم.',
          fr: '${action.label} — terminé.',
          es: '${action.label} — listo.',
        ).of(context),
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(
        context,
        const S(
          "Couldn't complete that — try again.",
          'معرفناش نكمل — جرب تاني.',
          fr: "Ça n'a pas abouti — réessayez.",
          es: 'No se pudo completar — inténtalo de nuevo.',
        ).of(context),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final accent = toneColor(colors, widget.tone);

    return Card(
      color: accent.withValues(alpha: 0.08),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: accent.withValues(alpha: 0.16),
                    child: Icon(widget.icon, color: accent),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.textSecondary),
                          ),
                        ],
                        if (widget.detail != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.detail!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.onTap != null)
                    Icon(Icons.chevron_right, color: colors.textMuted),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final action in widget.actions)
                    action.destructive
                        ? AppButton.destructive(
                            label: action.label,
                            icon: action.icon,
                            loading: _busy,
                            onPressed: _busy ? null : () => _run(action),
                          )
                        : AppButton.primary(
                            label: action.label,
                            icon: action.icon,
                            loading: _busy,
                            onPressed: _busy ? null : () => _run(action),
                          ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
