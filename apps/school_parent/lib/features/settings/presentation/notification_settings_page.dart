import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          const S('Notification settings', 'إعدادات الإشعارات').of(context),
        ),
      ),
      body: prefs == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                SectionHeader(
                  title: const S(
                    'Trip notifications',
                    'إشعارات الرحلة',
                  ).of(context),
                ),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: Text(
                          const S('Trip started', 'بدء الرحلة').of(context),
                        ),
                        subtitle: Text(
                          const S(
                            'Notify me when the bus starts its route',
                            'نبهني لما الأتوبيس يبدأ خط سيره',
                          ).of(context),
                        ),
                        value: prefs.tripStart,
                        onChanged: (value) =>
                            _apply((p) => p.copyWith(tripStart: value)),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: Text(
                          const S(
                            'Trip paused',
                            'توقف الرحلة مؤقتًا',
                          ).of(context),
                        ),
                        subtitle: Text(
                          const S(
                            'Notify me when the driver pauses',
                            'نبهني لما السواق يوقف مؤقتًا',
                          ).of(context),
                        ),
                        value: prefs.tripPause,
                        onChanged: (value) =>
                            _apply((p) => p.copyWith(tripPause: value)),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: Text(
                          const S('Trip ended', 'انتهاء الرحلة').of(context),
                        ),
                        subtitle: Text(
                          const S(
                            'Notify me when the trip completes or is cancelled',
                            'نبهني لما الرحلة تخلص أو تتلغي',
                          ).of(context),
                        ),
                        value: prefs.tripEnd,
                        onChanged: (value) =>
                            _apply((p) => p.copyWith(tripEnd: value)),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: Text(
                          const S(
                            'Arrival at pickup point',
                            'الوصول لنقطة الاستلام',
                          ).of(context),
                        ),
                        subtitle: Text(
                          const S(
                            "Notify me the moment the bus reaches my child's "
                                'pickup point',
                            'نبهني أول ما الأتوبيس يوصل نقطة استلام ابني',
                          ).of(context),
                        ),
                        value: prefs.arrival,
                        onChanged: (value) =>
                            _apply((p) => p.copyWith(arrival: value)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl3),
                SectionHeader(
                  title: const S(
                    'Heads-up timing',
                    'توقيت التنبيه',
                  ).of(context),
                ),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: Text(
                          const S(
                            'Heads-up before arrival',
                            'تنبيه قبل الوصول',
                          ).of(context),
                        ),
                        subtitle: Text(
                          prefs.minutesBefore > 0
                              ? S(
                                  'Notify me about ${prefs.minutesBefore} min '
                                      'before the bus arrives',
                                  'نبهني قبل وصول الأتوبيس بـ ${prefs.minutesBefore} '
                                      'دقيقة',
                                ).of(context)
                              : const S('Off', 'متوقف').of(context),
                        ),
                        value: prefs.minutesBefore > 0,
                        onChanged: (value) => _apply(
                          (p) => p.copyWith(
                            minutesBefore: value
                                ? (int.tryParse(_minutesController.text) ?? 10)
                                : 0,
                          ),
                        ),
                      ),
                      if (prefs.minutesBefore > 0) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            AppSpacing.lg,
                            AppSpacing.sm,
                            AppSpacing.lg,
                            AppSpacing.lg,
                          ),
                          child: Row(
                            children: [
                              Text(
                                const S(
                                  'Minutes before:',
                                  'الدقايق قبلها:',
                                ).of(context),
                                style: TextStyle(
                                  color: context.appColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: _minutesController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                  ),
                                  onSubmitted: (value) {
                                    final minutes = int.tryParse(value);
                                    if (minutes != null && minutes > 0) {
                                      _apply(
                                        (p) => p.copyWith(
                                          minutesBefore: minutes,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
