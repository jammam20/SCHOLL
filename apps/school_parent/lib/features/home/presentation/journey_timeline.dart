import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../../trips/domain/journey_stage.dart';
import 'journey_stage_visuals.dart';

/// The nine steps of [mainJourneyPath], in the words a parent would use.
/// Index-aligned with [mainJourneyPath] and with [reachedStepCount]'s
/// return value, which is the whole reason this list is a constant here
/// rather than built per-render.
const _stepLabels = [
  S('Trip scheduled', 'الرحلة متجدولة'),
  S('Trip started', 'الرحلة بدأت'),
  S('Bus is on the way', 'الأتوبيس في الطريق'),
  S('Bus approaching your stop', 'الأتوبيس قرّب من محطتك'),
  S('Bus arrived at your stop', 'الأتوبيس وصل محطتك'),
  S('Child boarded', 'الطفل ركب'),
  S('Bus continuing to school', 'الأتوبيس مكمّل للمدرسة'),
  S('Arrived at school', 'وصل المدرسة'),
  S('Trip completed', 'الرحلة خلصت'),
];

/// The index in [_stepLabels] of the step that *is* this child's own stop —
/// the one place where "stop N of M" from the real stop order belongs.
const _ownStopStepIndex = 4;

/// The index of the school's arrival step — the trip's fixed final stop.
const _schoolStepIndex = 7;

/// How far along today's trip is, step by step, for one child.
///
/// Everything up to [reachedStepCount] renders as done, the next one as
/// current, the rest as still to come. On [JourneyStage.cancelled] the
/// remaining steps are struck through instead of left as plain upcoming,
/// so "this didn't happen" reads differently from "this hasn't happened
/// yet" — and paused/emergency mark the step they interrupted rather than
/// silently freezing on a "current" step that is not, in fact, in progress.
///
/// [stopNumber]/[totalStops] come from the trip's real `stopOrder` (via
/// `computeParentTripEta`) and annotate the child's own stop with its true
/// position in today's run. A parent only ever sees their own child's
/// position plus the school as the final stop: firestore.rules makes the
/// other students on the bus unreadable here, so there is deliberately no
/// per-sibling stop list to draw.
class JourneyTimeline extends StatelessWidget {
  const JourneyTimeline({
    super.key,
    required this.stage,
    required this.hasBoarded,
    this.stopNumber,
    this.totalStops,
  });

  final JourneyStage stage;
  final bool hasBoarded;

  /// This child's 1-based position in the trip's full stop order, or null
  /// when the driver hasn't computed today's order yet (or this child
  /// isn't on it, e.g. marked absent).
  final int? stopNumber;

  /// How many stops today's order holds, including the school's own final
  /// stop. Null/zero before the order exists.
  final int? totalStops;

  bool get _hasStopPosition =>
      stopNumber != null && totalStops != null && totalStops! > 0;

  @override
  Widget build(BuildContext context) {
    final reached = reachedStepCount(stage, hasBoarded: hasBoarded);
    final tone = stageTone(stage);
    final accent = toneColor(context.appColors, tone);
    final isCancelled = stage == JourneyStage.cancelled;
    final isPaused = stage == JourneyStage.paused;
    final isEmergency = stage == JourneyStage.emergency;

    _StepState stateFor(int index) {
      if (index < reached) return _StepState.done;
      if (index > reached) {
        return isCancelled ? _StepState.cancelled : _StepState.upcoming;
      }
      if (isCancelled) return _StepState.cancelled;
      if (isPaused) return _StepState.paused;
      if (isEmergency) return _StepState.emergency;
      return _StepState.current;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _stepLabels.length; i++)
          _TimelineStep(
            index: i,
            label: _stepLabels[i].of(context),
            detail: _detailFor(context, i),
            state: stateFor(i),
            // The connector below a step is "travelled" once that step
            // itself is behind us — so the filled line runs right up to
            // the current node and stops there, never past it.
            connectorDone: i < reached,
            isLast: i == _stepLabels.length - 1,
            accent: accent,
          ),
      ],
    );
  }

  /// The one extra line a step is allowed to carry — and only when it is a
  /// real fact from the trip document, never a filler subtitle.
  String? _detailFor(BuildContext context, int index) {
    if (index == _ownStopStepIndex && _hasStopPosition) {
      return S(
        'Stop $stopNumber of $totalStops on today’s route',
        'المحطة رقم $stopNumber من $totalStops في خط النهاردة',
      ).of(context);
    }
    if (index == _schoolStepIndex && _hasStopPosition) {
      return const S(
        'The final stop on every trip',
        'آخر محطة في كل رحلة',
      ).of(context);
    }
    return null;
  }
}

enum _StepState { done, current, upcoming, paused, emergency, cancelled }

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.index,
    required this.label,
    required this.detail,
    required this.state,
    required this.connectorDone,
    required this.isLast,
    required this.accent,
  });

  final int index;
  final String label;
  final String? detail;
  final _StepState state;
  final bool connectorDone;
  final bool isLast;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.appColors;

    final (nodeColor, glyph) = switch (state) {
      _StepState.done => (tones.success, Icons.check_rounded),
      _StepState.current => (accent, null),
      _StepState.upcoming => (tones.border, null),
      _StepState.paused => (tones.warning, Icons.pause_rounded),
      _StepState.emergency => (tones.emergency, Icons.priority_high_rounded),
      _StepState.cancelled => (tones.disabled, Icons.close_rounded),
    };

    final isFilled = state != _StepState.upcoming;
    final isEmphasized =
        state == _StepState.current ||
        state == _StepState.paused ||
        state == _StepState.emergency;
    final isMuted =
        state == _StepState.upcoming || state == _StepState.cancelled;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                _StepNode(
                  color: nodeColor,
                  glyph: glyph,
                  filled: isFilled,
                  pulsing: state == _StepState.current,
                  // Only an unmarked upcoming/current node shows its
                  // number; a done/paused/cancelled node shows the glyph
                  // that says what happened to it instead.
                  number: glyph == null ? index + 1 : null,
                  surface: tones.surface,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: connectorDone ? tones.success : tones.border,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isEmphasized
                          ? FontWeight.w800
                          : (state == _StepState.done
                                ? FontWeight.w600
                                : FontWeight.w500),
                      color: isMuted ? tones.textMuted : tones.textPrimary,
                      decoration: state == _StepState.cancelled
                          ? TextDecoration.lineThrough
                          : null,
                      height: 1.2,
                    ),
                  ),
                  if (detail != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        detail!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tones.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single node on the rail. The current step gets a slow breathing halo
/// so the eye lands on "where we are now" without needing to read — turned
/// off (rendered as a plain static ring) whenever the platform asks for
/// reduced motion, per `design-system/MASTER.md` §10/§12.
class _StepNode extends StatefulWidget {
  const _StepNode({
    required this.color,
    required this.glyph,
    required this.filled,
    required this.pulsing,
    required this.number,
    required this.surface,
  });

  final Color color;
  final IconData? glyph;
  final bool filled;
  final bool pulsing;
  final int? number;
  final Color surface;

  @override
  State<_StepNode> createState() => _StepNodeState();
}

class _StepNodeState extends State<_StepNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _StepNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final shouldRun = widget.pulsing && !_reduceMotion;
    if (shouldRun && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!shouldRun && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final core = Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.filled ? widget.color : widget.surface,
        border: Border.all(color: widget.color, width: 2),
      ),
      alignment: Alignment.center,
      child: widget.glyph != null
          ? Icon(widget.glyph, size: 13, color: Colors.white)
          : Text(
              '${widget.number ?? ''}',
              style: TextStyle(
                fontSize: 10,
                height: 1,
                fontWeight: FontWeight.w800,
                color: widget.filled ? Colors.white : widget.color,
              ),
            ),
    );

    if (!widget.pulsing) return core;

    if (_reduceMotion) {
      return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: 0.18),
        ),
        child: core,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(
            alpha: 0.10 + _controller.value * 0.18,
          ),
        ),
        child: child,
      ),
      child: core,
    );
  }
}

/// The same nine-step progress, collapsed to one horizontal rail plus a
/// single line of text. Used wherever a full stepper would drown the
/// content — the multi-child home list, where four of these stack.
class JourneyProgressRail extends StatelessWidget {
  const JourneyProgressRail({
    super.key,
    required this.stage,
    required this.hasBoarded,
  });

  final JourneyStage stage;
  final bool hasBoarded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.appColors;
    final reached = reachedStepCount(stage, hasBoarded: hasBoarded);
    final total = mainJourneyPath.length;
    final tone = stageTone(stage);
    final accent = toneColor(tones, tone);
    final isCancelled = stage == JourneyStage.cancelled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < total; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: i == total - 1 ? 0 : 3,
                  ),
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: isCancelled
                          ? (i < reached
                                ? tones.disabled
                                : tones.border.withValues(alpha: 0.6))
                          : i < reached
                          ? tones.success
                          : i == reached
                          ? accent.withValues(alpha: 0.55)
                          : tones.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          // A cancelled trip has no meaningful "step N of 9" left to
          // report — it stopped being a sequence the moment it was called
          // off, so it just says what it is.
          isCancelled
              ? stageBadgeLabel(stage).of(context)
              : S(
                  'Step ${reached.clamp(1, total)} of $total · '
                      '${stageBadgeLabel(stage).of(context)}',
                  'الخطوة ${reached.clamp(1, total)} من $total · '
                      '${stageBadgeLabel(stage).of(context)}',
                ).of(context),
          style: theme.textTheme.bodySmall?.copyWith(
            color: tones.textSecondary,
          ),
        ),
      ],
    );
  }
}
