import 'package:flutter/material.dart';

import '../../../app/app_settings.dart';
import '../../trips/domain/journey_stage.dart';

/// A vertical checklist of a trip's 9-step lifecycle: everything up to
/// [reachedStepCount] renders as completed (filled, checked), the next one
/// as current (highlighted), and the rest as upcoming (outline only). On
/// [JourneyStage.cancelled] the remaining steps are struck through instead
/// of left as plain upcoming, so "this didn't happen" reads differently
/// from "this hasn't happened yet".
class JourneyTimeline extends StatelessWidget {
  const JourneyTimeline({super.key, required this.stage, required this.hasBoarded});

  final JourneyStage stage;
  final bool hasBoarded;

  static const _labels = [
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

  @override
  Widget build(BuildContext context) {
    final reached = reachedStepCount(stage, hasBoarded: hasBoarded);
    final isCancelled = stage == JourneyStage.cancelled;
    final isPaused = stage == JourneyStage.paused;
    final isEmergency = stage == JourneyStage.emergency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _labels.length; i++)
          _TimelineStep(
            label: _labels[i].of(context),
            isFirst: i == 0,
            isLast: i == _labels.length - 1,
            state: i < reached
                ? _StepState.completed
                : i == reached
                ? (isCancelled
                      ? _StepState.cancelled
                      : isPaused
                      ? _StepState.paused
                      : isEmergency
                      ? _StepState.emergency
                      : _StepState.current)
                : (isCancelled ? _StepState.cancelled : _StepState.upcoming),
          ),
      ],
    );
  }
}

enum _StepState { completed, current, upcoming, paused, emergency, cancelled }

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.isFirst,
    required this.isLast,
    required this.state,
  });

  final String label;
  final bool isFirst;
  final bool isLast;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (dotColor, lineColorAfter, icon) = switch (state) {
      _StepState.completed => (const Color(0xFF17B26A), colors.primary, Icons.check),
      _StepState.current => (colors.primary, colors.outlineVariant, null),
      _StepState.upcoming => (colors.outlineVariant, colors.outlineVariant, null),
      _StepState.paused => (const Color(0xFFF79009), colors.outlineVariant, Icons.pause),
      _StepState.emergency => (colors.error, colors.outlineVariant, Icons.priority_high),
      _StepState.cancelled => (colors.outlineVariant, colors.outlineVariant, Icons.close),
    };
    final isEmphasized = state == _StepState.current ||
        state == _StepState.paused ||
        state == _StepState.emergency;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                if (!isFirst)
                  SizedBox(
                    height: 4,
                    child: VerticalDivider(
                      width: 2,
                      thickness: 2,
                      color: colors.outlineVariant,
                    ),
                  ),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: state == _StepState.completed ||
                            state == _StepState.paused ||
                            state == _StepState.emergency ||
                            state == _StepState.cancelled
                        ? dotColor
                        : (state == _StepState.current
                              ? dotColor
                              : Colors.transparent),
                    border: Border.all(color: dotColor, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: icon != null
                      ? Icon(icon, size: 10, color: Colors.white)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: VerticalDivider(width: 2, thickness: 2, color: lineColorAfter),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18, top: 1),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isEmphasized ? FontWeight.w800 : FontWeight.w500,
                  color: state == _StepState.upcoming || state == _StepState.cancelled
                      ? colors.onSurfaceVariant
                      : colors.onSurface,
                  decoration: state == _StepState.cancelled
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
