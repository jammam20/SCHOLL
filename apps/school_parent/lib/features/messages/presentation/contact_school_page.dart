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

  /// The trip currently offered as context, resolved by the stream below.
  /// Assigned during build rather than through setState because nothing on
  /// this screen re-renders from it — it's only read at submit time, and
  /// the checkbox that governs whether it's used has its own state.
  SchoolTrip? _contextTrip;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
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

    setState(() => _sending = true);
    try {
      await ParentRequestsRepository().submitRequest(
        schoolId: widget.user.schoolId,
        parentUid: widget.user.uid,
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
        stream: TripsRepository().watchMyStudents(
          schoolId: widget.user.schoolId,
          parentUid: widget.user.uid,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: const [
                AppSkeleton(width: 220, height: 16),
                SizedBox(height: AppSpacing.lg),
                AppSkeleton(height: 56, borderRadius: AppRadius.md),
                SizedBox(height: AppSpacing.lg),
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
          // stay selected in a dropdown that no longer lists them.
          final selectedId =
              students.any((s) => s.id == _selectedStudentId)
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
              const _RoutingNotice(),
              const SizedBox(height: AppSpacing.xl2),
              SectionHeader(
                title: const S('What is this about?', 'الرسالة بخصوص إيه؟').of(
                  context,
                ),
              ),
              // A plain DropdownButton driven entirely by _selectedStudentId
              // rather than DropdownButtonFormField: the selection has to
              // stay valid against a *live* list of children, and a form
              // field keeps its own copy of the value that wouldn't follow
              // the `selectedId` sanitizing just above.
              InputDecorator(
                decoration: InputDecoration(
                  labelText: const S('Child', 'الطفل').of(context),
                  border: const OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: selectedId,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          const S(
                            'A general question',
                            'سؤال عام',
                          ).of(context),
                        ),
                      ),
                      for (final student in students)
                        DropdownMenuItem<String?>(
                          value: student.id,
                          child: Text(student.name),
                        ),
                    ],
                    onChanged: _sending
                        ? null
                        : (value) => setState(() {
                            _selectedStudentId = value;
                            _contextTrip = null;
                          }),
                  ),
                ),
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
                  border: const OutlineInputBorder(),
                  hintText: const S(
                    'e.g. My son will be picked up by his grandmother '
                        'tomorrow — can you let the driver know?',
                    'مثلاً: جدته هتستلمه بكرة — ممكن تبلغوا السواق؟',
                  ).of(context),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton.primary(
                label: const S('Send to school', 'ابعت للمدرسة').of(context),
                icon: Icons.send,
                loading: _sending,
                onPressed: () => _submit(students),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                const S(
                  'For anything urgent while the bus is moving, call your '
                      'school directly — this goes to their message queue, '
                      'not to an alert.',
                  'لو في حاجة مستعجلة والأتوبيس في الطريق، اتصل بالمدرسة '
                      'على طول — الرسالة دي بتروح لقائمة رسايلهم، مش تنبيه '
                      'عاجل.',
                ).of(context),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Says exactly where the message goes. A parent who thinks they're
/// texting the driver would wait for a reply that structurally cannot
/// arrive — the driver has no read access to this collection at all.
class _RoutingNotice extends StatelessWidget {
  const _RoutingNotice();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.info.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.school_outlined, color: colors.info, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              const S(
                'Your message goes to the school office. If the driver needs '
                    'to know something, the school passes it on — drivers '
                    "can't be messaged directly.",
                'رسالتك بتروح لإدارة المدرسة. لو في حاجة لازم السواق يعرفها، '
                    'المدرسة هي اللي بتبلغه — مفيش تواصل مباشر مع السواقين.',
              ).of(context),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Offers today's trip on the selected child's route as optional context,
/// so an admin reading the request knows which run it's about without the
/// parent having to describe it. Renders nothing when there's no trip on
/// record for today — there'd be nothing real to attach.
class _TripContextField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: TripsRepository().watchLatestTripForRoute(
        schoolId: schoolId,
        routeId: routeId,
      ),
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

        onTripResolved(trip);
        if (trip == null) return const SizedBox.shrink();

        final label = trip.routeName.isEmpty
            ? DateFormat.jm().format(trip.scheduledAt)
            : '${trip.routeName} · ${DateFormat.jm().format(trip.scheduledAt)}';

        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: attach,
          onChanged: enabled ? (value) => onChanged(value ?? false) : null,
          title: Text(
            const S(
              "Include today's trip",
              'أرفق رحلة النهاردة',
            ).of(context),
          ),
          subtitle: Text(
            label,
            style: TextStyle(color: context.appColors.textSecondary),
          ),
        );
      },
    );
  }
}
