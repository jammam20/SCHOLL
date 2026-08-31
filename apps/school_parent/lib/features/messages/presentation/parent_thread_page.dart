import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../../widgets/parent_ui.dart';
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

  /// How many messages the list had on the previous build, so the first
  /// render can jump straight to the bottom while a message arriving later
  /// animates there instead of teleporting mid-conversation.
  int _renderedMessageCount = 0;

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

  void _scrollToLatest(int messageCount) {
    if (messageCount == _renderedMessageCount) return;
    final isFirstRender = _renderedMessageCount == 0;
    _renderedMessageCount = messageCount;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (isFirstRender || MediaQuery.of(context).disableAnimations) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: AppDurations.stateSwitch,
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // The request this page was pushed with is a snapshot; the thread's own
    // status and "has the school seen it" flag keep moving while the parent
    // is reading. Re-using the existing watchMyRequests stream (rather than
    // adding a new per-document read) keeps the delivery indicator honest
    // without touching the repository's API.
    return StreamBuilder<List<ParentRequest>>(
      stream: _repository.watchMyRequests(
        schoolId: widget.user.schoolId,
        parentUid: widget.user.uid,
      ),
      builder: (context, threadSnapshot) {
        var thread = widget.request;
        for (final candidate in threadSnapshot.data ?? const <ParentRequest>[]) {
          if (candidate.id == widget.request.id) thread = candidate;
        }
        return _buildScaffold(context, thread);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, ParentRequest thread) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final studentName = thread.studentName;
    final isClosed = thread.status == ParentRequestStatus.closed;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              thread.subject.isEmpty
                  ? const S('General question', 'سؤال عام').of(context)
                  : thread.subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              studentName == null || studentName.isEmpty
                  ? const S('School office', 'إدارة المدرسة').of(context)
                  : S(
                      'School office · about $studentName',
                      'إدارة المدرسة · بخصوص $studentName',
                    ).of(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          InfoNotice(
            dense: true,
            icon: Icons.school_outlined,
            message: const S(
              "You're talking to the school office — they pass anything the "
                  "driver needs to know on to them.",
              'انت بتكلم إدارة المدرسة — وهم اللي بيبلغوا السواق باللي يهمه.',
            ).of(context),
          ),
          if (isClosed)
            InfoNotice(
              dense: true,
              tone: StatusTone.neutral,
              icon: Icons.check_circle_outline_rounded,
              message: const S(
                'The school marked this conversation closed.',
                'المدرسة قفلت المحادثة دي.',
              ).of(context),
            ),
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
                  return const _ThreadLoadingView();
                }

                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return EmptyStateView(
                    compact: true,
                    icon: Icons.chat_bubble_outline_rounded,
                    title: const S(
                      'No messages here yet',
                      'مفيش رسايل هنا لسه',
                    ).of(context),
                    message: const S(
                      'Write below and the school office will see it.',
                      'اكتب تحت وإدارة المدرسة هتشوفها.',
                    ).of(context),
                  );
                }

                _scrollToLatest(messages.length);

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final previous = index == 0 ? null : messages[index - 1];
                    final isLast = index == messages.length - 1;
                    final startsNewDay =
                        previous == null ||
                        !isSameDay(previous.createdAt, message.createdAt);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (startsNewDay)
                          _DaySeparator(date: message.createdAt),
                        _MessageBubble(
                          message: message,
                          // Only the first bubble of a run carries the
                          // sender's name, so a back-and-forth doesn't repeat
                          // "School" down the whole screen.
                          showSender:
                              previous == null ||
                              !isSameDay(previous.createdAt, message.createdAt) ||
                              previous.isFromParent != message.isFromParent,
                        ),
                        // The delivery state belongs to the conversation, not
                        // to each bubble: it's the thread's own unreadByAdmin
                        // flag, so it can only ever be shown once, under the
                        // parent's most recent message.
                        if (isLast && message.isFromParent)
                          _DeliveryStatus(seenBySchool: !thread.unreadByAdmin),
                      ],
                    );
                  },
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

/// Skeleton bubbles rather than a centered spinner — the conversation's shape
/// is predictable, so the first paint shouldn't be an empty screen.
class _ThreadLoadingView extends StatelessWidget {
  const _ThreadLoadingView();

  @override
  Widget build(BuildContext context) {
    Widget bubble({required bool fromParent, required double width}) => Align(
      alignment: fromParent
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: AppSkeleton(
          width: width,
          height: 52,
          borderRadius: AppRadius.lg,
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        bubble(fromParent: false, width: 220),
        bubble(fromParent: true, width: 180),
        bubble(fromParent: false, width: 240),
      ],
    );
  }
}

/// A centered "Today"/"Yesterday"/date rule between two calendar days of
/// conversation.
class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(child: Divider(color: colors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              friendlyDay(context, date),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Divider(color: colors.border)),
        ],
      ),
    );
  }
}

/// "Sent" vs "Seen by school", read from the thread's own `unreadByAdmin`
/// flag — the same flag the onParentMessageCreated Cloud Function maintains.
/// Nothing here is inferred or simulated: if the school hasn't opened the
/// thread, this says so.
class _DeliveryStatus extends StatelessWidget {
  const _DeliveryStatus({required this.seenBySchool});

  final bool seenBySchool;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = seenBySchool ? colors.success : colors.textMuted;
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(
            seenBySchool ? Icons.done_all_rounded : Icons.done_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            seenBySchool
                ? const S('Seen by school', 'المدرسة شافتها').of(context)
                : const S('Sent', 'اتبعتت').of(context),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.showSender});

  final ParentThreadMessage message;
  final bool showSender;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final isParent = message.isFromParent;
    final bubbleColor = isParent
        ? theme.colorScheme.primary
        : colors.surfaceElevated;
    final textColor = isParent
        ? theme.colorScheme.onPrimary
        : colors.textPrimary;

    // A squared-off corner on the sender's side gives each bubble a tail
    // without a custom painter, and reads correctly in both LTR and RTL
    // because the radii are directional.
    const round = Radius.circular(AppRadius.lg);
    const tail = Radius.circular(AppSpacing.xs);

    return Align(
      alignment: isParent
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.sm, top: showSender ? 2 : 0),
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg - 2,
          vertical: AppSpacing.md - 2,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          border: isParent ? null : Border.all(color: colors.border),
          borderRadius: BorderRadiusDirectional.only(
            topStart: round,
            topEnd: round,
            bottomStart: isParent ? round : tail,
            bottomEnd: isParent ? tail : round,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showSender && !isParent)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  const S('School office', 'إدارة المدرسة').of(context),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            Text(
              message.text,
              style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
            ),
            const SizedBox(height: 3),
            Text(
              DateFormat.jm().format(message.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isParent
                    ? theme.colorScheme.onPrimary.withValues(alpha: 0.75)
                    : colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The message box. Stateful only so the send button can light up the moment
/// there's something to send — the send itself still runs through the page's
/// own [_ParentThreadPageState._send].
class _Composer extends StatefulWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  late bool _hasText = widget.controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final canSend = _hasText && !widget.sending;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  enabled: !widget.sending,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: const S(
                      'Write a message…',
                      'اكتب رسالة…',
                    ).of(context),
                    filled: true,
                    fillColor: colors.background,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1.6,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                  onSubmitted: (_) => widget.onSend(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AnimatedContainer(
                duration: AppDurations.stateSwitch,
                curve: Curves.easeOut,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: canSend
                      ? theme.colorScheme.primary
                      : colors.disabled.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  tooltip: const S('Send', 'ابعت').of(context),
                  onPressed: canSend ? widget.onSend : null,
                  icon: widget.sending
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          size: 19,
                          color: canSend
                              ? theme.colorScheme.onPrimary
                              : colors.textMuted,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
