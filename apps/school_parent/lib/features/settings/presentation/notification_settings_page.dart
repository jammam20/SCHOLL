import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:school_shared/school_shared.dart';

import '../data/notification_prefs_repository.dart';

/// Lets a parent turn each kind of push notification on or off, and tune
/// how many minutes of heads-up they want before the bus arrives — loaded
/// once, then edited locally and persisted in the background so toggles
/// respond instantly instead of waiting on a round trip.
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final _repository = NotificationPrefsRepository();
  final _minutesController = TextEditingController();
  NotificationPrefs? _prefs;

  /// The presets offered as one-tap choices. A parent who wants a value
  /// that isn't here can still type any number into the field beside them —
  /// both write the same `minutesBefore` integer.
  static const _minutePresets = [5, 10, 15, 30];

  @override
  void initState() {
    super.initState();
    _repository.watch().first.then((prefs) {
      if (!mounted) return;
      setState(() => _prefs = prefs);
      _minutesController.text = '${prefs.minutesBefore}';
    });
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _apply(
    NotificationPrefs Function(NotificationPrefs current) update,
  ) async {
    final previous = _prefs;
    if (previous == null) return;
    final next = update(previous);
    setState(() => _prefs = next);

    try {
      await _repository.update(next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _prefs = previous);
      AppSnackbar.error(
        context,
        const S(
          "Couldn't save that — try again.",
          'معرفناش نحفظ ده — جرب تاني.',
        ).of(context),
      );
    }
  }

  void _setMinutes(int minutes) {
    if (minutes <= 0) return;
    // Both the presets and the free-entry field land here, and the field
    // re-submits whenever focus leaves it — so a value that didn't actually
    // change must not cost a Firestore write.
    if (_prefs?.minutesBefore == minutes) return;
    _minutesController.text = '$minutes';
    _apply((p) => p.copyWith(minutesBefore: minutes));
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    final colors = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          const S('Notification settings', 'إعدادات الإشعارات').of(context),
        ),
      ),
      body: prefs == null
          ? const _PrefsLoadingView()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xl3,
              ),
              children: [
                InfoNotice(
                  icon: Icons.notifications_active_outlined,
                  message: const S(
                    'These control the alerts this app sends to your phone. '
                        'Everything still appears in your notifications list '
                        'either way.',
                    'دي بتتحكم في التنبيهات اللي بتوصل موبايلك. كل حاجة هتفضل '
                        'تظهر في قائمة الإشعارات على أي حال.',
                  ).of(context),
                ),
                const SizedBox(height: AppSpacing.xl2),
                SectionHeader(
                  title: const S(
                    'Trip notifications',
                    'إشعارات الرحلة',
                  ).of(context),
                ),
                AppListCard(
                  children: [
                    _PrefSwitch(
                      icon: Icons.play_circle_outline_rounded,
                      tone: colors.info,
                      title: const S('Trip started', 'بدء الرحلة').of(context),
                      subtitle: const S(
                        'When the bus starts its route',
                        'لما الأتوبيس يبدأ خط سيره',
                      ).of(context),
                      value: prefs.tripStart,
                      onChanged: (value) =>
                          _apply((p) => p.copyWith(tripStart: value)),
                    ),
                    _PrefSwitch(
                      icon: Icons.pause_circle_outline_rounded,
                      tone: colors.warning,
                      title: const S(
                        'Trip paused',
                        'توقف الرحلة مؤقتًا',
                      ).of(context),
                      subtitle: const S(
                        'When the driver pauses',
                        'لما السواق يوقف مؤقتًا',
                      ).of(context),
                      value: prefs.tripPause,
                      onChanged: (value) =>
                          _apply((p) => p.copyWith(tripPause: value)),
                    ),
                    _PrefSwitch(
                      icon: Icons.flag_outlined,
                      tone: colors.info,
                      title: const S('Trip ended', 'انتهاء الرحلة').of(context),
                      subtitle: const S(
                        'When the trip completes or is cancelled',
                        'لما الرحلة تخلص أو تتلغي',
                      ).of(context),
                      value: prefs.tripEnd,
                      onChanged: (value) =>
                          _apply((p) => p.copyWith(tripEnd: value)),
                    ),
                    _PrefSwitch(
                      icon: Icons.location_on_outlined,
                      tone: colors.success,
                      title: const S(
                        'Arrival at pickup point',
                        'الوصول لنقطة الاستلام',
                      ).of(context),
                      subtitle: const S(
                        "The moment the bus reaches my child's pickup point",
                        'أول ما الأتوبيس يوصل نقطة استلام ابني',
                      ).of(context),
                      value: prefs.arrival,
                      onChanged: (value) =>
                          _apply((p) => p.copyWith(arrival: value)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl3),
                SectionHeader(
                  title: const S('Heads-up timing', 'توقيت التنبيه').of(context),
                  subtitle: const S(
                    'An early warning before the bus reaches your stop, so '
                        'nobody is waiting outside longer than they need to.',
                    'تنبيه بدري قبل ما الأتوبيس يوصل محطتك، عشان محدش يستنى '
                        'بره أكتر من اللازم.',
                  ).of(context),
                ),
                AppListCard(
                  children: [
                    _PrefSwitch(
                      icon: Icons.timer_outlined,
                      tone: colors.info,
                      title: const S(
                        'Heads-up before arrival',
                        'تنبيه قبل الوصول',
                      ).of(context),
                      subtitle: prefs.minutesBefore > 0
                          ? S(
                              'About ${prefs.minutesBefore} minutes before the '
                                  'bus arrives',
                              'قبل وصول الأتوبيس بـ ${prefs.minutesBefore} '
                                  'دقيقة تقريبًا',
                            ).of(context)
                          : const S('Off', 'متوقف').of(context),
                      value: prefs.minutesBefore > 0,
                      onChanged: (value) => _apply(
                        (p) => p.copyWith(
                          minutesBefore: value
                              ? (int.tryParse(_minutesController.text) ?? 10)
                              : 0,
                        ),
                      ),
                    ),
                    if (prefs.minutesBefore > 0)
                      _MinutesPicker(
                        presets: _minutePresets,
                        current: prefs.minutesBefore,
                        controller: _minutesController,
                        onPreset: _setMinutes,
                        onSubmitted: (value) {
                          final minutes = int.tryParse(value);
                          if (minutes != null && minutes > 0) {
                            _setMinutes(minutes);
                          } else {
                            // Put the field back to the value actually
                            // stored, so a typo never leaves the UI showing
                            // a number that was never saved.
                            _minutesController.text = '${prefs.minutesBefore}';
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _PrefsLoadingView extends StatelessWidget {
  const _PrefsLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: const [
        AppSkeleton(height: 64, borderRadius: AppRadius.md),
        SizedBox(height: AppSpacing.xl2),
        AppSkeleton(width: 180, height: 18),
        SizedBox(height: AppSpacing.md),
        AppSkeleton(height: 240, borderRadius: AppRadius.lg),
      ],
    );
  }
}

/// One preference row: a tinted icon, what the alert is, when it fires, and
/// the switch itself.
class _PrefSwitch extends StatelessWidget {
  const _PrefSwitch({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: icon,
      tone: tone,
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

/// Quick presets plus a free-entry field — both write the same
/// `minutesBefore` integer the Cloud Functions read.
class _MinutesPicker extends StatelessWidget {
  const _MinutesPicker({
    required this.presets,
    required this.current,
    required this.controller,
    required this.onPreset,
    required this.onSubmitted,
  });

  final List<int> presets;
  final int current;
  final TextEditingController controller;
  final ValueChanged<int> onPreset;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            const S('Minutes before arrival', 'الدقايق قبل الوصول').of(context),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final preset in presets)
                _MinutePresetChip(
                  minutes: preset,
                  selected: preset == current,
                  onTap: () => onPreset(preset),
                ),
              SizedBox(
                width: 92,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: colors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    suffixText: const S('min', 'د').of(context),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1.6,
                      ),
                    ),
                  ),
                  onSubmitted: onSubmitted,
                  onTapOutside: (_) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    onSubmitted(controller.text);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MinutePresetChip extends StatelessWidget {
  const _MinutePresetChip({
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final accent = theme.colorScheme.primary;

    return Material(
      color: selected ? accent.withValues(alpha: 0.12) : colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg - 2,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? accent : colors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Text(
            S('$minutes min', '$minutes د').of(context),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? accent : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
