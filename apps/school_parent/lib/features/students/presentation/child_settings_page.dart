import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../../messages/presentation/contact_school_page.dart';
import '../data/students_repository.dart';

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

  Future<void> _savePickupPersons(List<AuthorizedPickupPerson> next) async {
    final previous = _pickupPersons;
    setState(() {
      _pickupPersons = next;
      _savingPickupPersons = true;
    });
    try {
      await StudentsRepository().setAuthorizedPickupPersons(
        schoolId: widget.user.schoolId,
        studentId: widget.student.id,
        persons: next,
      );
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
  }

  Future<void> _addPickupPerson() async {
    final person = await showDialog<AuthorizedPickupPerson>(
      context: context,
      builder: (_) => _AddPickupPersonDialog(
        id: StudentsRepository().newPickupPersonId(widget.user.schoolId),
      ),
    );
    if (person == null) return;
    await _savePickupPersons([..._pickupPersons, person]);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          S(
            '${student.name} · Settings',
            '${student.name} · الإعدادات',
          ).of(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          SectionHeader(
            title: const S('Attendance', 'الحضور').of(context),
          ),
          Container(
            decoration: BoxDecoration(
              color: _absentToday
                  ? colors.warning.withValues(alpha: 0.08)
                  : colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: _absentToday
                    ? colors.warning.withValues(alpha: 0.3)
                    : colors.border,
              ),
            ),
            child: SwitchListTile(
              title: Text(const S('Absent today', 'غايب النهاردة').of(context)),
              subtitle: Text(
                _absentToday
                    ? S(
                        "The bus won't stop at ${student.name}'s pickup point "
                            'today.',
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
          ),
          const SizedBox(height: AppSpacing.xl3),
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
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: colors.info.withValues(alpha: 0.24)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: colors.info, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    const S(
                      'This list tells the school and the driver who you '
                          'have authorized. The driver checks the name '
                          "against it — the app doesn't verify anyone's "
                          'identity, and no one on this list gets an account '
                          'or access to your data.',
                      'القايمة دي بتقول للمدرسة والسواق مين اللي انت مصرّح '
                          'له. السواق بيراجع الاسم عليها — التطبيق مش '
                          'بيتحقق من هوية حد، ومحدش في القايمة دي بياخد '
                          'حساب أو وصول لبياناتك.',
                    ).of(context),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_pickupPersons.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.lg,
                  horizontal: AppSpacing.md,
                ),
                child: Text(
                  S(
                    'No one added yet — only the parents linked to '
                        '${student.name} are on record.',
                    'محدش متضاف لسه — أولياء أمور ${student.name} بس هما '
                        'المسجلين.',
                  ).of(context),
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < _pickupPersons.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colors.info.withValues(alpha: 0.12),
                        child: Icon(
                          Icons.person_outline,
                          color: colors.info,
                          size: 20,
                        ),
                      ),
                      title: Text(_pickupPersons[i].name),
                      subtitle: Text(
                        _pickupPersonSubtitle(context, _pickupPersons[i]),
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      trailing: IconButton(
                        tooltip: const S('Remove', 'شيل').of(context),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _savingPickupPersons
                            ? null
                            : () => _removePickupPerson(_pickupPersons[i]),
                      ),
                    ),
                  ],
                ],
              ),
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
          SectionHeader(
            title: const S('Route & pickup', 'الخط ونقطة الاستلام').of(context),
            subtitle: const S(
              'Set by your school — read-only here.',
              'بيحددها المدرسة — للعرض بس هنا.',
            ).of(context),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.route),
                  title: Text(const S('Route', 'الخط').of(context)),
                  subtitle: Text(
                    hasRoute
                        ? const S('Assigned', 'متحدد').of(context)
                        : const S(
                            'Not assigned yet — contact your school.',
                            'لسه مش متحدد — كلم مدرستك.',
                          ).of(context),
                  ),
                  trailing: StatusBadge(
                    label: hasRoute
                        ? const S('Assigned', 'متحدد').of(context)
                        : const S('Missing', 'ناقص').of(context),
                    tone: hasRoute ? StatusTone.success : StatusTone.warning,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(const S('Pickup point', 'نقطة الاستلام').of(context)),
                  subtitle: Text(
                    student.hasLocation
                        ? const S('Set by the school', 'محددة من المدرسة').of(
                            context,
                          )
                        : const S(
                            'Not set yet — contact your school.',
                            'لسه مش متحددة — كلم مدرستك.',
                          ).of(context),
                  ),
                  trailing: StatusBadge(
                    label: student.hasLocation
                        ? const S('Set', 'محددة').of(context)
                        : const S('Missing', 'ناقص').of(context),
                    tone: student.hasLocation
                        ? StatusTone.success
                        : StatusTone.warning,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl3),
          SectionHeader(
            title: const S('Need something changed?', 'محتاج تغيّر حاجة؟').of(
              context,
            ),
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
