import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

/// Reason picker for reporting a post (Feature: Parent Community). Returns
/// the chosen reason and optional free-text details, or `null` if
/// cancelled — the caller (post detail page) does the actual
/// [CommunityRepository.reportPost] call so this dialog stays a pure
/// picker, matching how [showAppConfirmDialog] separates "what was chosen"
/// from "what happens next".
Future<({CommunityReportReason reason, String? details})?> showReportPostDialog(
  BuildContext context,
) {
  return showDialog<({CommunityReportReason reason, String? details})>(
    context: context,
    builder: (context) => const _ReportPostDialog(),
  );
}

class _ReportPostDialog extends StatefulWidget {
  const _ReportPostDialog();

  @override
  State<_ReportPostDialog> createState() => _ReportPostDialogState();
}

class _ReportPostDialogState extends State<_ReportPostDialog> {
  CommunityReportReason _reason = CommunityReportReason.inappropriate;
  final _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  String _reasonLabel(BuildContext context, CommunityReportReason reason) {
    return switch (reason) {
      CommunityReportReason.inappropriate => const S(
        'Inappropriate content',
        'محتوى غير مناسب',
      ).of(context),
      CommunityReportReason.abuse => const S('Abuse', 'إساءة').of(context),
      CommunityReportReason.misleading => const S(
        'Misleading information',
        'معلومات مضللة',
      ).of(context),
      CommunityReportReason.spam => const S('Spam', 'سبام').of(context),
      CommunityReportReason.other => const S('Other', 'أخرى').of(context),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(const S('Report post', 'إبلاغ عن المنشور').of(context)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final reason in CommunityReportReason.values)
              InkWell(
                onTap: () => setState(() => _reason = reason),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        _reason == reason
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: _reason == reason
                            ? Theme.of(context).colorScheme.primary
                            : context.appColors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_reasonLabel(context, reason))),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _detailsController,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: const S(
                  'Additional details (optional)',
                  'تفاصيل إضافية (اختياري)',
                ).of(context),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(const S('Cancel', 'إلغاء').of(context)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            reason: _reason,
            details: _detailsController.text.trim().isEmpty
                ? null
                : _detailsController.text.trim(),
          )),
          child: Text(const S('Report', 'إبلاغ').of(context)),
        ),
      ],
    );
  }
}
