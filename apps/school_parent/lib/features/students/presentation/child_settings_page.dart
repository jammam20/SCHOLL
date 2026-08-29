import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../data/students_repository.dart';

/// Per-child settings: mark them absent for today (so the driver's pickup
/// order skips their home and the bus doesn't detour for nothing), and a
/// quick look at their route/pickup-point setup.
class ChildSettingsPage extends StatefulWidget {
  const ChildSettingsPage({
    super.key,
    required this.schoolId,
    required this.student,
  });

  final String schoolId;
  final Student student;

  @override
  State<ChildSettingsPage> createState() => _ChildSettingsPageState();
}

class _ChildSettingsPageState extends State<ChildSettingsPage> {
  late bool _absentToday = widget.student.isAbsentToday;
  bool _saving = false;

  Future<void> _toggleAbsent(bool value) async {
    final previous = _absentToday;
    setState(() {
      _absentToday = value;
      _saving = true;
    });
    try {
      await StudentsRepository().setAbsent(
        schoolId: widget.schoolId,
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
        ],
      ),
    );
  }
}
