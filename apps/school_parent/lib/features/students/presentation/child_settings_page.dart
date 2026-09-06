import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../../widgets/parent_ui.dart';
import '../../messages/presentation/contact_school_page.dart';
import '../data/students_repository.dart';
import 'child_location_picker_page.dart';

/// Per-child settings: mark them absent for today (so the driver's pickup
/// order skips their home and the bus doesn't detour for nothing), manage
/// who is allowed to collect them, a quick look at their route/pickup-point
/// setup, and a way to reach the school about this child.
class ChildSettingsPage extends StatefulWidget {
  const ChildSettingsPage({
    super.key,
    required this.user,
    required this.student,
  });

  final AppUser user;
  final Student student;

  @override
  State<ChildSettingsPage> createState() => _ChildSettingsPageState();
}

class _ChildSettingsPageState extends State<ChildSettingsPage> {
  late bool _absentToday = widget.student.isAbsentToday;
  bool _saving = false;

  /// The authorized-pickup list is edited in place and written back whole
  /// (see StudentsRepository.setAuthorizedPickupPersons). Held locally and
  /// rolled back on failure, the same optimistic pattern the absence
  /// toggle below already uses — the student document this page was opened
  /// with is a snapshot, so nothing else would refresh it.
  late List<AuthorizedPickupPerson> _pickupPersons = List.of(
    widget.student.authorizedPickupPersons,
  );
  bool _savingPickupPersons = false;

  /// Future absence dates, held and rolled back the same optimistic way as
  /// [_pickupPersons] — see StudentsRepository.setScheduledAbsences.
  late List<String> _scheduledDates = List.of(
    widget.student.scheduledAbsenceDates,
  )..sort();
  bool _savingScheduledDates = false;

  /// Feature: Parent can add child location. Same optimistic/snapshot
  /// reasoning as above — this page was opened with a point-in-time
  /// Student, so a just-submitted proposal is tracked locally rather than
  /// waiting for a refetch that would never come.
  late bool _locationRequestPending = widget.student.hasPendingLocationRequest;
  bool _submittingLocation = false;

  Future<void> _proposeLocation() async {
    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => ChildLocationPickerPage(
          studentName: widget.student.name,
          initialPosition: widget.student.hasLocation
              ? LatLng(widget.student.latitude!, widget.student.longitude!)
              : null,
        ),
      ),
    );
    if (picked == null || !mounted) return;

    setState(() => _submittingLocation = true);
    try {
      await StudentsRepository().proposeLocationChange(
        schoolId: widget.user.schoolId,
        studentId: widget.student.id,
        latitude: picked.latitude,
        longitude: picked.longitude,
      );
      if (!mounted) return;
      setState(() => _locationRequestPending = true);
      AppSnackbar.success(
        context,
        const S(
          'Sent to your school for review.',
          'اتبعتت لمدرستك للمراجعة.',
        ).of(context),
      );
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
      if (mounted) setState(() => _submittingLocation = false);
    }
  }

  Future<void> _toggleAbsent(bool value) async {
    final previous = _absentToday;
    setState(() {
      _absentToday = value;
      _saving = true;
    });
    try {
      await StudentsRepository().setAbsent(
        schoolId: widget.user.schoolId,
        studentId: widget.student.id,
        studentName: widget.student.name,
        absentOn: value ? todayIsoDate() : null,
      );
      // The switch flipping is not, by itself, proof the school heard about
      // it. Confirm the write landed — this is the one action on this screen
      // that changes what the driver's app does today.
      if (mounted) {
        AppSnackbar.success(
          context,
          value
              ? S(
                  '${widget.student.name} is marked absent today.',
                  'تم تحديد ${widget.student.name} غايب النهاردة.',
                ).of(context)
              : S(
                  '${widget.student.name} is riding today.',
                  '${widget.student.name} هيركب النهاردة.',
                ).of(context),
        );
      }
    } catch (_) {
      // The optimistic toggle above already flipped the switch; if the
      // write actually failed (offline, a rules rejection, a transient
      // Firestore error) it must revert, otherwise the parent believes
      // their child is marked absent/present when the driver's app never
      // saw the change — matching the rollback pattern already used in
      // NotificationSettingsPage._apply.
      if (mounted) {
        setState(() => _absentToday = previous);
        AppSnackbar.error(
          context,
          const S(
            "Couldn't save that — try again.",
            'معرفناش نحفظ ده — جرب تاني.',
          ).of(context),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Returns whether the save actually succeeded. Callers that show their
  /// own success message (`_addPickupPerson`) must check this first — a
  /// caught failure here already shows its own error snackbar, and showing
  /// a *second*, unconditional success snackbar on top of that regardless
  /// of the outcome (the bug this fixes) told a parent a pickup
  /// authorization was recorded when it had just been silently rolled back.
  Future<bool> _savePickupPersons(List<AuthorizedPickupPerson> next) async {
    final previous = _pickupPersons;
    setState(() {
      _pickupPersons = next;
      _savingPickupPersons = true;
    });
    var succeeded = false;
    try {
      await StudentsRepository().setAuthorizedPickupPersons(
        schoolId: widget.user.schoolId,
        studentId: widget.student.id,
        persons: next,
      );
      succeeded = true;
    } catch (_) {
      if (mounted) {
        setState(() => _pickupPersons = previous);
        AppSnackbar.error(
          context,
          const S(
            "Couldn't save that — try again.",
            'معرفناش نحفظ ده — جرب تاني.',
          ).of(context),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPickupPersons = false);
    }
    return succeeded;
  }

  /// Returns whether the save actually succeeded — see _savePickupPersons's
  /// doc comment for why callers that show their own success message
  /// (_addScheduledDate, _removeScheduledDate) must check this first.
  Future<bool> _saveScheduledDates(List<String> next) async {
    final previous = _scheduledDates;
    final sorted = List.of(next)..sort();
    setState(() {
      _scheduledDates = sorted;
      _savingScheduledDates = true;
    });
    var succeeded = false;
    try {
      await StudentsRepository().setScheduledAbsences(
        schoolId: widget.user.schoolId,
        studentId: widget.student.id,
        dates: sorted,
      );
      succeeded = true;
    } catch (_) {
      if (mounted) {
        setState(() => _scheduledDates = previous);
        AppSnackbar.error(
          context,
          const S(
            "Couldn't save that — try again.",
            'معرفناش نحفظ ده — جرب تاني.',
          ).of(context),
        );
      }
    } finally {
      if (mounted) setState(() => _savingScheduledDates = false);
    }
    return succeeded;
  }

  Future<void> _addScheduledDate() async {
    final now = DateTime.now();
    final lastDate = now.add(const Duration(days: 365));

    // showDatePicker asserts that initialDate itself passes
    // selectableDayPredicate, so open on the first day that isn't already
    // scheduled rather than on tomorrow unconditionally — otherwise a parent
    // whose next free day is taken would crash the picker.
    var initialDate = now.add(const Duration(days: 1));
    while (initialDate.isBefore(lastDate) &&
        _scheduledDates.contains(isoDateOnly(initialDate))) {
      initialDate = initialDate.add(const Duration(days: 1));
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: lastDate,
      helpText: const S(
        'Pick an absence date',
        'اختار يوم الغياب',
      ).of(context),
      // A day that's already scheduled is shown as unavailable rather than
      // silently doing nothing when tapped.
      selectableDayPredicate: (day) =>
          !_scheduledDates.contains(isoDateOnly(day)),
    );
    if (picked == null) return;
    final iso = isoDateOnly(picked);
    if (_scheduledDates.contains(iso)) return;
    final succeeded = await _saveScheduledDates([..._scheduledDates, iso]);
    if (!mounted || !succeeded) return;
    AppSnackbar.success(
      context,
      S(
        'Absence scheduled for ${_absenceDateLabel(context, iso)}.',
        'تم تحديد غياب يوم ${_absenceDateLabel(context, iso)}.',
      ).of(context),
    );
  }

  Future<void> _removeScheduledDate(String date) async {
    final succeeded = await _saveScheduledDates(
      _scheduledDates.where((d) => d != date).toList(),
    );
    if (!mounted || !succeeded) return;
    AppSnackbar.info(
      context,
      S(
        'Absence on ${_absenceDateLabel(context, date)} removed.',
        'اتشال غياب يوم ${_absenceDateLabel(context, date)}.',
      ).of(context),
    );
  }

  Future<void> _addPickupPerson() async {
    final person = await showDialog<AuthorizedPickupPerson>(
      context: context,
      builder: (_) => _AddPickupPersonDialog(
        id: StudentsRepository().newPickupPersonId(widget.user.schoolId),
      ),
    );
    if (person == null) return;
    final succeeded = await _savePickupPersons([..._pickupPersons, person]);
    if (!mounted || !succeeded) return;
    AppSnackbar.success(
      context,
      S(
        '${person.name} can now collect ${widget.student.name}.',
        '${person.name} بقى مصرّح له يستلم ${widget.student.name}.',
      ).of(context),
    );
  }

  Future<void> _removePickupPerson(AuthorizedPickupPerson person) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: const S(
        'Remove this person?',
        'تشيل الشخص ده؟',
      ).of(context),
      message: S(
        '${person.name} will no longer be listed as authorized to collect '
            '${widget.student.name}.',
        '${person.name} مش هيفضل مكتوب إنه مصرّح له يستلم '
            '${widget.student.name}.',
      ).of(context),
      confirmLabel: const S('Remove', 'شيل').of(context),
      destructive: true,
    );
    if (confirmed != true) return;
    await _savePickupPersons(
      _pickupPersons.where((p) => p.id != person.id).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    final colors = context.appColors;
    final hasRoute = student.routeId != null && student.routeId!.isNotEmpty;
    // `absentOn` and `scheduledAbsenceDates` are two independent fields and
    // either can cover today (see Student.isAbsentOn). When it's the
    // scheduled list that covers today, the switch below can't clear it —
    // that date has to be removed from the list — so say so plainly instead
    // of leaving a switch that appears not to work.
    final todayIsScheduled = _scheduledDates.contains(todayIsoDate());

    return Scaffold(
      appBar: AppBar(
        title: Text(const S('Child settings', 'إعدادات الطفل').of(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xl3,
        ),
        children: [
          _ChildHeader(
            name: student.name,
            absentToday: _absentToday,
          ),
          const SizedBox(height: AppSpacing.xl2),

          // ---- Attendance -------------------------------------------------
          SectionHeader(
            title: const S('Attendance', 'الحضور').of(context),
            subtitle: const S(
              "Tell the driver when your child isn't riding, so the bus "
                  "doesn't detour for a stop nobody is waiting at.",
              'قول للسواق لما ابنك مش هيركب، عشان الأتوبيس ما يلفش على محطة '
                  'محدش مستنيه فيها.',
            ).of(context),
          ),
          AnimatedContainer(
            duration: AppDurations.stateSwitch,
            decoration: BoxDecoration(
              color: _absentToday
                  ? colors.warning.withValues(alpha: 0.08)
                  : colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: _absentToday
                    ? colors.warning.withValues(alpha: 0.35)
                    : colors.border,
              ),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  title: Text(
                    const S('Absent today', 'غايب النهاردة').of(context),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    _absentToday
                        ? S(
                            "The bus won't stop at ${student.name}'s pickup "
                                'point today.',
                            'الأتوبيس مش هيقف عند نقطة استلام ${student.name} '
                                'النهاردة.',
                          ).of(context)
                        : S(
                            "Turn this on if ${student.name} isn't riding the "
                                'bus today.',
                            'شغّل ده لو ${student.name} مش هيركب الأتوبيس '
                                'النهاردة.',
                          ).of(context),
                    style: TextStyle(color: colors.textSecondary),
                  ),
                  value: _absentToday,
                  onChanged: _saving ? null : _toggleAbsent,
                ),
                // The resulting state, spelled out with the actual date, so
                // "did that save?" never needs a second guess.
                if (_absentToday)
                  _ResultBanner(
                    tone: StatusTone.warning,
                    icon: Icons.event_busy_rounded,
                    text: S(
                      'Marked absent for today, '
                          '${DateFormat('EEE, d MMM').format(DateTime.now())}. '
                          'Your school and the driver can see this.',
                      'متحدد غايب النهاردة '
                          '${DateFormat('EEE, d MMM').format(DateTime.now())}. '
                          'المدرسة والسواق شايفين ده.',
                    ).of(context),
                  ),
                if (todayIsScheduled)
                  _ResultBanner(
                    tone: StatusTone.info,
                    icon: Icons.event_repeat_rounded,
                    text: const S(
                      "Today is also on the scheduled list below — remove it "
                          'there to have your child ride today.',
                      'النهاردة كمان موجود في المواعيد المحددة تحت — شيله من '
                          'هناك لو عايز ابنك يركب النهاردة.',
                    ).of(context),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl2),

          // ---- Scheduled absences ----------------------------------------
          SectionHeader(
            title: const S(
              'Scheduled absences',
              'غياب محدد مقدمًا',
            ).of(context),
            subtitle: const S(
              'Plan ahead instead of remembering to switch the toggle on '
                  'the day.',
              'خطط قدام بدل ما تفتكر تشغّل المفتاح في يومه.',
            ).of(context),
          ),
          if (_scheduledDates.isEmpty)
            _EmptyPanel(
              icon: Icons.event_available_outlined,
              text: const S(
                'No dates scheduled.',
                'مفيش أيام محددة.',
              ).of(context),
            )
          else
            AppListCard(
              children: [
                for (final date in _scheduledDates)
                  _ScheduledDateRow(
                    iso: date,
                    enabled: !_savingScheduledDates,
                    onRemove: () => _removeScheduledDate(date),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.md),
          AppButton.secondary(
            label: const S(
              'Schedule an absence date',
              'حدد يوم غياب',
            ).of(context),
            icon: Icons.event_available_outlined,
            loading: _savingScheduledDates,
            onPressed: _addScheduledDate,
          ),
          const SizedBox(height: AppSpacing.xl3),

          // ---- Authorized pickup ------------------------------------------
          SectionHeader(
            title: const S('Who can collect', 'مين يقدر يستلمه').of(context),
            subtitle: S(
              'The people you authorize to collect ${student.name}.',
              'الناس اللي بتصرّح لهم يستلموا ${student.name}.',
            ).of(context),
          ),
          // Says exactly what this list is and isn't. It records the
          // parent's own authorization and gives the driver a name to
          // expect — there is no ID document check, no photo, and no
          // identity verification of any kind behind it, and claiming
          // otherwise would be worse than saying nothing.
          InfoNotice(
            message: const S(
              'This list tells the school and the driver who you have '
                  'authorized. The driver checks the name against it — the '
                  "app doesn't verify anyone's identity, and no one on this "
                  'list gets an account or access to your data.',
              'القايمة دي بتقول للمدرسة والسواق مين اللي انت مصرّح له. السواق '
                  'بيراجع الاسم عليها — التطبيق مش بيتحقق من هوية حد، ومحدش '
                  'في القايمة دي بياخد حساب أو وصول لبياناتك.',
            ).of(context),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_pickupPersons.isEmpty)
            _EmptyPanel(
              icon: Icons.person_outline_rounded,
              text: S(
                'No one added yet — only the parents linked to '
                    '${student.name} are on record.',
                'محدش متضاف لسه — أولياء أمور ${student.name} بس هما '
                    'المسجلين.',
              ).of(context),
            )
          else
            AppListCard(
              children: [
                for (final person in _pickupPersons)
                  _PickupPersonRow(
                    person: person,
                    enabled: !_savingPickupPersons,
                    onRemove: () => _removePickupPerson(person),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.md),
          AppButton.secondary(
            label: const S(
              'Add an authorized person',
              'ضيف شخص مصرّح له',
            ).of(context),
            icon: Icons.person_add_alt,
            loading: _savingPickupPersons,
            onPressed: _addPickupPerson,
          ),
          const SizedBox(height: AppSpacing.xl3),

          // ---- Route & pickup ---------------------------------------------
          SectionHeader(
            title: const S('Route & pickup', 'الخط ونقطة الاستلام').of(context),
            subtitle: const S(
              'Set by your school — read-only here.',
              'بيحددها المدرسة — للعرض بس هنا.',
            ).of(context),
          ),
          AppListCard(
            children: [
              SettingsTile(
                icon: Icons.route_rounded,
                tone: hasRoute ? colors.success : colors.warning,
                title: const S('Route', 'الخط').of(context),
                subtitle: hasRoute
                    ? const S('Assigned', 'متحدد').of(context)
                    : const S(
                        'Not assigned yet — contact your school.',
                        'لسه مش متحدد — كلم مدرستك.',
                      ).of(context),
                trailing: StatusBadge(
                  label: hasRoute
                      ? const S('Assigned', 'متحدد').of(context)
                      : const S('Missing', 'ناقص').of(context),
                  tone: hasRoute ? StatusTone.success : StatusTone.warning,
                ),
              ),
              SettingsTile(
                icon: Icons.location_on_rounded,
                tone: _locationRequestPending
                    ? colors.info
                    : student.hasLocation
                    ? colors.success
                    : colors.warning,
                title: const S('Pickup point', 'نقطة الاستلام').of(context),
                subtitle: _locationRequestPending
                    ? const S(
                        'Your suggested location is waiting for the school '
                            'to review it.',
                        'الموقع اللي اقترحته في انتظار مراجعة المدرسة.',
                      ).of(context)
                    : student.hasLocation
                    ? const S(
                        'Set by the school',
                        'محددة من المدرسة',
                      ).of(context)
                    : const S(
                        'Not set yet — contact your school.',
                        'لسه مش متحددة — كلم مدرستك.',
                      ).of(context),
                trailing: StatusBadge(
                  label: _locationRequestPending
                      ? const S('Pending', 'قيد المراجعة').of(context)
                      : student.hasLocation
                      ? const S('Set', 'محددة').of(context)
                      : const S('Missing', 'ناقص').of(context),
                  tone: _locationRequestPending
                      ? StatusTone.info
                      : student.hasLocation
                      ? StatusTone.success
                      : StatusTone.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Feature: Parent can add child location. The school still has
          // the final say — see StudentsRepository.proposeLocationChange —
          // so this is framed as a suggestion, not a change, and is
          // disabled while one is already pending review.
          AppButton.secondary(
            label: _locationRequestPending
                ? const S('Suggestion pending review', 'الاقتراح قيد المراجعة')
                    .of(context)
                : const S('Suggest a pickup location', 'اقترح نقطة استلام')
                    .of(context),
            icon: Icons.edit_location_alt_outlined,
            loading: _submittingLocation,
            onPressed: _locationRequestPending ? null : _proposeLocation,
          ),
          const SizedBox(height: AppSpacing.xl3),

          // ---- Contact the school -----------------------------------------
          SectionHeader(
            title: const S(
              'Need something changed?',
              'محتاج تغيّر حاجة؟',
            ).of(context),
            subtitle: const S(
              'Route, pickup point and bus assignments are set by the '
                  'school — send them a message and they will pass anything '
                  'the driver needs on to them.',
              'الخط ونقطة الاستلام والأتوبيس بتحددهم المدرسة — ابعتلهم رسالة '
                  'وهما هيبلغوا السواق باللي يهمه.',
            ).of(context),
          ),
          AppButton.secondary(
            label: S(
              'Contact the school about ${student.name}',
              'كلّم المدرسة بخصوص ${student.name}',
            ).of(context),
            icon: Icons.mail_outline,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContactSchoolPage(
                  user: widget.user,
                  initialStudent: student,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Who this screen is about, and the one fact that matters most today.
class _ChildHeader extends StatelessWidget {
  const _ChildHeader({required this.name, required this.absentToday});

  final String name;
  final bool absentToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          InitialAvatar(name: name, size: 52),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                StatusBadge(
                  label: absentToday
                      ? const S('Absent today', 'غايب النهاردة').of(context)
                      : const S('Riding today', 'هيركب النهاردة').of(context),
                  tone: absentToday ? StatusTone.warning : StatusTone.success,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The "here's what that did" strip under an action that changed something.
class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    required this.tone,
    required this.icon,
    required this.text,
  });

  final StatusTone tone;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final accent = toneColor(colors, tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: accent.withValues(alpha: 0.24))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A quiet "nothing here yet" panel for a list that has a real add action
/// directly beneath it — lighter than a full [EmptyStateView], which would
/// out-shout the button that fixes it.
class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.textMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduledDateRow extends StatelessWidget {
  const _ScheduledDateRow({
    required this.iso,
    required this.enabled,
    required this.onRemove,
  });

  final String iso;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final relative = _absenceRelativeLabel(context, iso);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md - 2),
            ),
            child: Icon(
              Icons.event_busy_rounded,
              size: 19,
              color: colors.warning,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _absenceDateLabel(context, iso),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                if (relative != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    relative,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: const S('Remove', 'شيل').of(context),
            icon: const Icon(Icons.close_rounded),
            color: colors.textMuted,
            onPressed: enabled ? onRemove : null,
          ),
        ],
      ),
    );
  }
}

class _PickupPersonRow extends StatelessWidget {
  const _PickupPersonRow({
    required this.person,
    required this.enabled,
    required this.onRemove,
  });

  final AuthorizedPickupPerson person;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          InitialAvatar(name: person.name, size: 38, color: colors.info),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _pickupPersonSubtitle(context, person),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: const S('Remove', 'شيل').of(context),
            icon: const Icon(Icons.delete_outline_rounded),
            color: colors.textMuted,
            onPressed: enabled ? onRemove : null,
          ),
        ],
      ),
    );
  }
}

/// A stored `yyyy-MM-dd` absence date, rendered the way a person reads a
/// date. Falls back to the raw stored string if it somehow isn't parseable,
/// rather than hiding a date that really is set on the record.
String _absenceDateLabel(BuildContext context, String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  return friendlyDay(context, parsed);
}

/// "In 4 days" under the date itself — null when the date already reads as
/// relative ("Today", "Tomorrow"), where repeating it would be noise.
String? _absenceRelativeLabel(BuildContext context, String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(parsed.year, parsed.month, parsed.day);
  final days = target.difference(today).inDays;
  if (days <= 1) return null;
  return S('In $days days', 'بعد $days أيام').of(context);
}

String _pickupPersonSubtitle(
  BuildContext context,
  AuthorizedPickupPerson person,
) {
  final parts = [
    if (person.relationship != null && person.relationship!.isNotEmpty)
      person.relationship!,
    if (person.phone != null && person.phone!.isNotEmpty) person.phone!,
  ];
  if (parts.isEmpty) {
    return const S(
      'Authorized to collect',
      'مصرّح له بالاستلام',
    ).of(context);
  }
  return parts.join(' · ');
}

class _AddPickupPersonDialog extends StatefulWidget {
  const _AddPickupPersonDialog({required this.id});

  final String id;

  @override
  State<_AddPickupPersonDialog> createState() => _AddPickupPersonDialogState();
}

class _AddPickupPersonDialogState extends State<_AddPickupPersonDialog> {
  final _nameController = TextEditingController();
  final _relationshipController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _nameMissing = false;

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameMissing = true);
      return;
    }
    final relationship = _relationshipController.text.trim();
    final phone = _phoneController.text.trim();
    Navigator.pop(
      context,
      AuthorizedPickupPerson(
        id: widget.id,
        name: name,
        relationship: relationship.isEmpty ? null : relationship,
        phone: phone.isEmpty ? null : phone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        const S('Add an authorized person', 'ضيف شخص مصرّح له').of(context),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              const S(
                'The driver will check this name at the door. Nobody added '
                    'here gets an account or access to your data.',
                'السواق هيراجع الاسم ده عند الباب. محدش بيتضاف هنا بياخد حساب '
                    'أو وصول لبياناتك.',
              ).of(context),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: const S('Full name', 'الاسم بالكامل').of(context),
                errorText: _nameMissing
                    ? const S(
                        'A name is required.',
                        'الاسم مطلوب.',
                      ).of(context)
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _relationshipController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: const S(
                  'Relationship (optional)',
                  'صلة القرابة (اختياري)',
                ).of(context),
                hintText: const S('e.g. Grandmother', 'مثلاً: الجدة').of(
                  context,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: const S(
                  'Phone (optional)',
                  'التليفون (اختياري)',
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
          onPressed: _submit,
          child: Text(const S('Add', 'إضافة').of(context)),
        ),
      ],
    );
  }
}
