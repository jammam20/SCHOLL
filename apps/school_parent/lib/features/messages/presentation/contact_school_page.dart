import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../trips/data/trips_repository.dart';
import '../data/parent_requests_repository.dart';

/// "Contact the school about [child]" — the parent's only outbound channel,
/// and deliberately so.
///
/// A parent can't message a driver directly anywhere in this app: this form
/// writes to `schools/{schoolId}/parentRequests`, which only the school's
/// admin can read, and the admin passes on whatever the driver needs to
/// know. The copy on this screen says that plainly rather than implying the
/// driver will see it.
class ContactSchoolPage extends StatefulWidget {
  const ContactSchoolPage({
    super.key,
    required this.user,
    this.initialStudent,
  });

  final AppUser user;

  /// Pre-selects a child when the parent got here from that child's own
  /// settings screen. Null when they came from the requests list, where
  /// they pick (or skip) a child themselves.
  final Student? initialStudent;

  @override
  State<ContactSchoolPage> createState() => _ContactSchoolPageState();
}

class _ContactSchoolPageState extends State<ContactSchoolPage> {
  final _messageController = TextEditingController();
  late String? _selectedStudentId = widget.initialStudent?.id;
  bool _attachTrip = true;
  bool _sending = false;

  /// Whether there's anything to send yet — drives the primary button's
  /// enabled state.
  bool _hasMessage = false;

  /// The trip currently offered as context, resolved by the stream below.
  /// Assigned during build rather than through setState because nothing on
  /// this screen re-renders from it — it's only read at submit time, and
  /// the checkbox that governs whether it's used has its own state.
  SchoolTrip? _contextTrip;

  // Feature: keyboard bug fix. `_onMessageChanged` below calls setState on
  // every keystroke (to flip the send button's enabled state), which
  // re-runs build() — if `TripsRepository().watchMyStudents(...)` were
  // called fresh inside build() (as it used to be), each of those
  // keystroke-triggered rebuilds would hand the StreamBuilder a brand-new
  // Stream object. StreamBuilder treats a changed stream reference as
  // "resubscribe": it drops straight back to its loading branch — which
  // here is a bare skeleton ListView with no TextField in it at all — for
  // one frame, unmounting the very TextField the parent is typing into and
  // taking the keyboard down with it. Caching the stream once removes the
  // only thing that was changing between those rebuilds.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _studentsStream =
      TripsRepository().watchMyStudents(
        schoolId: widget.user.schoolId,
        parentUid: widget.user.uid,
      );

  @override
  void initState() {
    super.initState();
    // Drives the send button's enabled state — the parent shouldn't have to
    // tap a live-looking button to be told the message is empty.
    _messageController.addListener(_onMessageChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _onMessageChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _hasMessage) setState(() => _hasMessage = hasText);
  }

  Future<void> _submit(List<Student> students) async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      AppSnackbar.info(
        context,
        const S(
          'Write your message first.',
          'اكتب رسالتك الأول.',
        ).of(context),
      );
      return;
    }

    Student? student;
    for (final candidate in students) {
      if (candidate.id == _selectedStudentId) student = candidate;
    }
    final trip = _attachTrip ? _contextTrip : null;

    final subject = student == null
        ? const S('General question', 'سؤال عام').of(context)
        : S('About ${student.name}', 'بخصوص ${student.name}').of(context);

    setState(() => _sending = true);
    try {
      await ParentRequestsRepository().submitRequest(
        schoolId: widget.user.schoolId,
        parentUid: widget.user.uid,
        subject: subject,
        message: message,
        studentId: student?.id,
        studentName: student?.name,
        tripId: trip?.id,
      );
      if (!mounted) return;
      AppSnackbar.success(
        context,
        const S(
          'Sent to your school.',
          'اتبعتت لمدرستك.',
        ).of(context),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppSnackbar.error(
        context,
        const S(
          "Couldn't send that — check your connection and try again.",
          'معرفناش نبعتها — اتأكد من الاتصال وجرب تاني.',
        ).of(context),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          const S('Contact your school', 'كلّم مدرستك').of(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _studentsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: const [
                AppSkeleton(height: 72, borderRadius: AppRadius.md),
                SizedBox(height: AppSpacing.xl2),
                AppSkeleton(width: 220, height: 16),
                SizedBox(height: AppSpacing.lg),
                AppSkeleton(height: 56, borderRadius: AppRadius.md),
                SizedBox(height: AppSpacing.xl2),
                AppSkeleton(height: 140, borderRadius: AppRadius.md),
              ],
            );
          }
          if (snapshot.hasError) {
            return ErrorStateView(
              message: const S(
                "Couldn't load your children — check your connection and "
                    'try again.',
                'معرفناش نحمّل بيانات أبنائك — اتأكد من الاتصال وجرب تاني.',
              ).of(context),
            );
          }

          final students = (snapshot.data?.docs ?? const [])
              .map((doc) => Student.fromMap(doc.id, doc.data()))
              .toList();

          // A child who was unlinked while this screen was open shouldn't
          // stay selected in a picker that no longer lists them.
          final selectedId = students.any((s) => s.id == _selectedStudentId)
              ? _selectedStudentId
              : null;
          final selected = selectedId == null
              ? null
              : students.firstWhere((s) => s.id == selectedId);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xl3,
            ),
            children: [
              InfoNotice(
                icon: Icons.school_outlined,
                title: const S(
                  'This goes to the school office',
                  'الرسالة دي بتروح لإدارة المدرسة',
                ).of(context),
                message: const S(
                  'If the driver needs to know something, the school passes '
                      "it on — drivers can't be messaged directly.",
                  'لو في حاجة لازم السواق يعرفها، المدرسة هي اللي بتبلغه — '
                      'مفيش تواصل مباشر مع السواقين.',
                ).of(context),
              ),
              const SizedBox(height: AppSpacing.xl2),
              SectionHeader(
                title: const S(
                  'What is this about?',
                  'الرسالة بخصوص إيه؟',
                ).of(context),
                subtitle: const S(
                  'Naming a child helps the office answer faster.',
                  'لما تحدد الطفل، الإدارة بترد أسرع.',
                ).of(context),
              ),
              // Selectable chips rather than a dropdown: a parent has a
              // handful of children, and every option being visible at once
              // is both faster and clearer than a menu. The selection is
              // still driven entirely by _selectedStudentId against the
              // *live* list above, which is what keeps an unlinked child
              // from staying selected.
              _ChildPicker(
                students: students,
                selectedId: selectedId,
                enabled: !_sending,
                onChanged: (value) => setState(() {
                  _selectedStudentId = value;
                  _contextTrip = null;
                }),
              ),
              if (selected != null &&
                  selected.routeId != null &&
                  selected.routeId!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _TripContextField(
                  schoolId: widget.user.schoolId,
                  routeId: selected.routeId!,
                  attach: _attachTrip,
                  enabled: !_sending,
                  onTripResolved: (trip) => _contextTrip = trip,
                  onChanged: (value) => setState(() => _attachTrip = value),
                ),
              ],
              const SizedBox(height: AppSpacing.xl2),
              SectionHeader(
                title: const S('Your message', 'رسالتك').of(context),
              ),
              TextField(
                controller: _messageController,
                enabled: !_sending,
                minLines: 5,
                maxLines: 10,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.surface,
                  alignLabelWithHint: true,
                  contentPadding: const EdgeInsets.all(AppSpacing.lg),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.6,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  hintText: const S(
                    'e.g. My son will be picked up by his grandmother '
                        'tomorrow — can you let the driver know?',
                    'مثلاً: جدته هتستلمه بكرة — ممكن تبلغوا السواق؟',
                  ).of(context),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton.primary(
                label: const S('Send to school', 'ابعت للمدرسة').of(context),
                icon: Icons.send_rounded,
                loading: _sending,
                onPressed: _hasMessage ? () => _submit(students) : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              InfoNotice(
                tone: StatusTone.warning,
                icon: Icons.phone_in_talk_outlined,
                message: const S(
                  'For anything urgent while the bus is moving, call your '
                      'school directly — this goes to their message queue, '
                      'not to an alert.',
                  'لو في حاجة مستعجلة والأتوبيس في الطريق، اتصل بالمدرسة '
                      'على طول — الرسالة دي بتروح لقائمة رسايلهم، مش تنبيه '
                      'عاجل.',
                ).of(context),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The "who is this about" picker: one chip per linked child plus a general
/// option. Purely a presentation of `students` — it adds no child of its own
/// and offers nothing that isn't in the live list.
class _ChildPicker extends StatelessWidget {
  const _ChildPicker({
    required this.students,
    required this.selectedId,
    required this.enabled,
    required this.onChanged,
  });

  final List<Student> students;
  final String? selectedId;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    // A parent with no linked children still has a real reason to write —
    // "my child isn't showing up in the app" being the obvious one — so the
    // form stays usable and simply says there's nobody to attach.
    if (students.isEmpty) {
      return InfoNotice(
        tone: StatusTone.neutral,
        icon: Icons.child_care_outlined,
        message: const S(
          "You don't have a child linked yet, so this will be sent as a "
              'general question.',
          'مفيش طفل مرتبط بحسابك لسه، فالرسالة هتتبعت كسؤال عام.',
        ).of(context),
      );
    }

    // Keeps the group's own label available to screen readers now that the
    // dropdown's `labelText` is gone.
    return Semantics(
      label: const S('Child', 'الطفل').of(context),
      container: true,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          _PickerChip(
            label: const S('A general question', 'سؤال عام').of(context),
            icon: Icons.help_outline_rounded,
            selected: selectedId == null,
            enabled: enabled,
            onTap: () => onChanged(null),
          ),
          for (final student in students)
            _PickerChip(
              label: student.name,
              icon: Icons.child_care_outlined,
              selected: selectedId == student.id,
              enabled: enabled,
              onTap: () => onChanged(student.id),
            ),
        ],
      ),
    );
  }
}

class _PickerChip extends StatelessWidget {
  const _PickerChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
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
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: AppDurations.stateSwitch,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg - 2,
            vertical: AppSpacing.md - 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? accent : colors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_rounded : icon,
                size: 16,
                color: selected
                    ? accent
                    : (enabled ? colors.textMuted : colors.disabled),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? accent
                      : (enabled ? colors.textPrimary : colors.disabled),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Offers today's trip on the selected child's route as optional context,
/// so an admin reading the request knows which run it's about without the
/// parent having to describe it. Renders nothing when there's no trip on
/// record for today — there'd be nothing real to attach.
class _TripContextField extends StatefulWidget {
  const _TripContextField({
    required this.schoolId,
    required this.routeId,
    required this.attach,
    required this.enabled,
    required this.onTripResolved,
    required this.onChanged,
  });

  final String schoolId;
  final String routeId;
  final bool attach;
  final bool enabled;
  final ValueChanged<SchoolTrip?> onTripResolved;
  final ValueChanged<bool> onChanged;

  @override
  State<_TripContextField> createState() => _TripContextFieldState();
}

class _TripContextFieldState extends State<_TripContextField> {
  // Feature: keyboard bug fix (same pattern as _ContactSchoolPageState's
  // _studentsStream) — this widget is rebuilt fresh on every keystroke in
  // the parent form (it's inline in that build(), not const), so a stream
  // constructed directly inside build() here would resubscribe on every
  // keystroke too. Cached per routeId instead, so it only actually changes
  // when the parent switches which child (and therefore which route) this
  // is about.
  late String _streamRouteId = widget.routeId;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _tripStream =
      TripsRepository().watchLatestTripForRoute(
        schoolId: widget.schoolId,
        routeId: widget.routeId,
      );

  @override
  void didUpdateWidget(covariant _TripContextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.routeId != _streamRouteId) {
      _streamRouteId = widget.routeId;
      _tripStream = TripsRepository().watchLatestTripForRoute(
        schoolId: widget.schoolId,
        routeId: widget.routeId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _tripStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        SchoolTrip? trip;
        if (docs.isNotEmpty) {
          final candidate = SchoolTrip.fromMap(docs.first.id, docs.first.data());
          final now = DateTime.now();
          final isToday =
              candidate.scheduledAt.year == now.year &&
              candidate.scheduledAt.month == now.month &&
              candidate.scheduledAt.day == now.day;
          if (isToday) trip = candidate;
        }

        widget.onTripResolved(trip);
        if (trip == null) return const SizedBox.shrink();

        final label = trip.routeName.isEmpty
            ? DateFormat.jm().format(trip.scheduledAt)
            : '${trip.routeName} · ${DateFormat.jm().format(trip.scheduledAt)}';

        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: CheckboxListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            value: widget.attach,
            onChanged: widget.enabled
                ? (value) => widget.onChanged(value ?? false)
                : null,
            title: Text(
              const S(
                "Include today's trip",
                'أرفق رحلة النهاردة',
              ).of(context),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              label,
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
        );
      },
    );
  }
}
