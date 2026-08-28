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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    final colorScheme = Theme.of(context).colorScheme;

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
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: _absentToday ? colorScheme.errorContainer : null,
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
              ),
              value: _absentToday,
              onChanged: _saving ? null : _toggleAbsent,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.route),
                  title: Text(const S('Route', 'الخط').of(context)),
                  subtitle: Text(
                    student.routeId == null || student.routeId!.isEmpty
                        ? const S(
                            'Not assigned yet — contact your school.',
                            'لسه مش متحدد — كلم مدرستك.',
                          ).of(context)
                        : const S('Assigned', 'متحدد').of(context),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
