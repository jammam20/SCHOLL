import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../data/parent_messages_repository.dart';

/// The admin's side of one parent conversation — a real chat, matching the
/// parent app's own ParentThreadPage exactly (bubble alignment flipped: the
/// admin's own messages sit on the trailing side here).
class AdminThreadPage extends StatefulWidget {
  const AdminThreadPage({super.key, required this.schoolId, required this.request});

  final String schoolId;
  final ParentRequest request;

  @override
  State<AdminThreadPage> createState() => _AdminThreadPageState();
}

class _AdminThreadPageState extends State<AdminThreadPage> {
  final _repository = ParentMessagesRepository();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    final uid = _uid;
    if (uid != null && widget.request.unreadByAdmin) {
      _repository.markRead(
        schoolId: widget.schoolId,
        requestId: widget.request.id,
        adminUid: uid,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final uid = _uid;
    final text = _controller.text.trim();
    if (uid == null || text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await _repository.sendMessage(
        schoolId: widget.schoolId,
        requestId: widget.request.id,
        adminUid: uid,
        text: text,
      );
      _controller.clear();
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(
        context,
        const S(
          "Couldn't send that — check your connection and try again.",
          'معرفناش نبعتها — اتأكد من الاتصال وجرب تاني.',
        ).of(context),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _close() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: const S('Close this conversation?', 'تقفل المحادثة دي؟').of(context),
      message: const S(
        'The parent can still see it, but it moves out of your open inbox.',
        'ولي الأمر لسه هيشوفها، بس هتتشال من صندوق الوارد المفتوح عندك.',
      ).of(context),
      confirmLabel: const S('Close', 'قفل').of(context),
    );
    if (confirmed != true || !mounted) return;
    await _repository.closeThread(schoolId: widget.schoolId, requestId: widget.request.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return Scaffold(
      appBar: AppBar(
        title: Text(request.subject.isEmpty ? request.parentUid : request.subject),
        actions: [
          if (request.status != ParentRequestStatus.closed)
            IconButton(
              tooltip: const S('Close conversation', 'قفل المحادثة').of(context),
              icon: const Icon(Icons.check_circle_outline),
              onPressed: _close,
            ),
        ],
      ),
      body: Column(
        children: [
          if (request.studentName != null && request.studentName!.isNotEmpty)
            _ContextBanner(
              label: S(
                'About ${request.studentName}',
                'بخصوص ${request.studentName}',
              ).of(context),
            ),
          Expanded(
            child: StreamBuilder<List<ParentThreadMessage>>(
              stream: _repository.watchMessages(
                schoolId: widget.schoolId,
                requestId: request.id,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const ErrorStateView(compact: true);
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: messages.length,
                  itemBuilder: (context, index) =>
                      _MessageBubble(message: messages[index]),
                );
              },
            ),
          ),
          _Composer(controller: _controller, sending: _sending, onSend: _send),
        ],
      ),
    );
  }
}

class _ContextBanner extends StatelessWidget {
  const _ContextBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      color: colors.info.withValues(alpha: 0.08),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colors.textSecondary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ParentThreadMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // The admin's own messages read as "sent" (trailing side) here — the
    // mirror image of the parent app's bubble alignment.
    final isMine = !message.isFromParent;

    return Align(
      alignment: isMine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isMine
              ? Theme.of(context).colorScheme.primary
              : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  const S('Parent', 'ولي الأمر').of(context),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textMuted,
                  ),
                ),
              ),
            Text(
              message.text,
              style: TextStyle(
                color: isMine
                    ? Theme.of(context).colorScheme.onPrimary
                    : colors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat.jm().format(message.createdAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isMine
                    ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.75)
                    : colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !sending,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: const S(
                    'Reply to the parent…',
                    'رد على ولي الأمر…',
                  ).of(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
