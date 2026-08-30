import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../data/parent_requests_repository.dart';

/// The actual conversation for one [ParentRequest] thread — a real chat,
/// not a single message + a status badge, so a parent can keep talking to
/// the school about the same thing instead of every reply starting a new,
/// disconnected entry.
class ParentThreadPage extends StatefulWidget {
  const ParentThreadPage({super.key, required this.user, required this.request});

  final AppUser user;
  final ParentRequest request;

  @override
  State<ParentThreadPage> createState() => _ParentThreadPageState();
}

class _ParentThreadPageState extends State<ParentThreadPage> {
  final _repository = ParentRequestsRepository();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.request.unreadByParent) {
      _repository.markReadByParent(
        schoolId: widget.user.schoolId,
        requestId: widget.request.id,
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
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await _repository.sendMessage(
        schoolId: widget.user.schoolId,
        requestId: widget.request.id,
        parentUid: widget.user.uid,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.request.subject)),
      body: Column(
        children: [
          const _RoutingBanner(),
          Expanded(
            child: StreamBuilder<List<ParentThreadMessage>>(
              stream: _repository.watchMessages(
                schoolId: widget.user.schoolId,
                requestId: widget.request.id,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorStateView(
                    message: const S(
                      "Couldn't load this conversation — check your "
                          'connection and try again.',
                      'معرفناش نحمّل المحادثة دي — اتأكد من الاتصال وجرب '
                          'تاني.',
                    ).of(context),
                  );
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
          _Composer(
            controller: _controller,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _RoutingBanner extends StatelessWidget {
  const _RoutingBanner();

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
        const S(
          "You're talking to the school office — they pass anything the "
              "driver needs to know on to them.",
          'انت بتكلم إدارة المدرسة — وهم اللي بيبلغوا السواق باللي يهمه.',
        ).of(context),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
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
    final isParent = message.isFromParent;

    return Align(
      alignment: isParent
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isParent
              ? Theme.of(context).colorScheme.primary
              : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isParent)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  const S('School', 'المدرسة').of(context),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textMuted,
                  ),
                ),
              ),
            Text(
              message.text,
              style: TextStyle(
                color: isParent
                    ? Theme.of(context).colorScheme.onPrimary
                    : colors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat.jm().format(message.createdAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isParent
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
                    'Write a message…',
                    'اكتب رسالة…',
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
