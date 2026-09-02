import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../../../widgets/activity_timeline.dart';
import '../../routes/data/routes_repository.dart';
import '../data/students_repository.dart';

/// A unified student profile/detail view (Feature: unified profile/detail
/// system) — everything an admin already had scattered across the
/// students-list row and the "Manage student" dialog, brought into one
/// place plus a real activity timeline, rather than a second data model.
/// Every field shown here reads from the same `Student` document the rest
/// of the app already uses; nothing is invented (no class/section, no
/// direct bus/driver assignment — those genuinely don't exist on a
/// student record in this system, only a route).
class StudentDetailPage extends StatelessWidget {
  const StudentDetailPage({super.key, required this.schoolId, required this.studentId});

  final String schoolId;
  final String studentId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(const S('Student', 'الطالب').of(context))),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('students')
            .doc(studentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const ErrorStateView();
          }
          if (!snapshot.hasData) {
            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.xl),
              itemCount: 5,
              itemBuilder: (_, _) => const AppSkeletonListTile(),
            );
          }
          final data = snapshot.data!.data();
          if (data == null) {
            return EmptyStateView(
              icon: Icons.person_off_outlined,
              title: const S(
                'This student no longer exists.',
                'الطالب ده مبقاش موجود.',
              ).of(context),
            );
          }
          final student = Student.fromMap(studentId, data);
          return _StudentDetailBody(schoolId: schoolId, student: student);
        },
      ),
    );
  }
}

class _StudentDetailBody extends StatelessWidget {
  const _StudentDetailBody({required this.schoolId, required this.student});

  final String schoolId;
  final Student student;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xl3,
          ),
          children: [
            Row(
              children: [
                InitialAvatar(name: student.name, size: 56),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          'ID: ${student.id}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusBadge(
                      label: student.isActive
                          ? const S('Active', 'نشط').of(context)
                          : const S('Archived', 'مؤرشف').of(context),
                      tone: student.isActive
                          ? StatusTone.success
                          : StatusTone.neutral,
                    ),
                    if (student.isAbsentToday) ...[
                      const SizedBox(height: 4),
                      StatusBadge(
                        label: const S('Absent today', 'غايب النهاردة')
                            .of(context),
                        tone: StatusTone.warning,
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl2),

            SectionHeader(
              title: const S('Transportation', 'النقل').of(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: RoutesRepository().watchRoutes(schoolId),
              builder: (context, snapshot) {
                final routeName = student.routeId == null ||
                        student.routeId!.isEmpty
                    ? null
                    : (snapshot.data?.docs
                                .where((doc) => doc.id == student.routeId)
                                .firstOrNull
                                ?.data()['name']
                            as String?) ??
                        student.routeId;
                return AppListCard(
                  children: [
                    SettingsTile(
                      icon: Icons.route_rounded,
                      tone: routeName == null ? colors.warning : colors.success,
                      title: const S('Assigned route', 'الخط المخصص')
                          .of(context),
                      subtitle: routeName ??
                          const S('Not assigned', 'مش متحدد').of(context),
                    ),
                    SettingsTile(
                      icon: Icons.location_on_rounded,
                      tone: student.hasLocation ? colors.success : colors.warning,
                      title: const S(
                        'Pickup / drop-off location',
                        'نقطة الاستلام/التسليم',
                      ).of(context),
                      subtitle: student.hasLocation
                          ? '${student.latitude!.toStringAsFixed(5)}, '
                              '${student.longitude!.toStringAsFixed(5)}'
                          : const S(
                              'Not set',
                              'مش متحددة',
                            ).of(context),
                    ),
                    if (student.hasPendingLocationRequest)
                      SettingsTile(
                        icon: Icons.pending_actions_outlined,
                        tone: colors.info,
                        title: const S(
                          'Pending location request',
                          'طلب موقع قيد المراجعة',
                        ).of(context),
                        subtitle: '${student.pendingLatitude!.toStringAsFixed(5)}, '
                            '${student.pendingLongitude!.toStringAsFixed(5)}',
                        trailing: StatusBadge(
                          label: const S('Pending', 'قيد المراجعة').of(context),
                          tone: StatusTone.info,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl2),

            SectionHeader(
              title: const S('Parents / guardians', 'أولياء الأمور').of(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: StudentsRepository().watchParentMembers(schoolId),
              builder: (context, snapshot) {
                final names = {
                  for (final doc in snapshot.data?.docs ?? const [])
                    doc.id: doc.data()['displayName']?.toString() ?? doc.id,
                };
                if (student.parentIds.isEmpty) {
                  return EmptyStateView(
                    compact: true,
                    icon: Icons.family_restroom_outlined,
                    title: const S(
                      'No parent linked yet',
                      'مفيش ولي أمر مرتبط لسه',
                    ).of(context),
                  );
                }
                return AppListCard(
                  children: [
                    for (final uid in student.parentIds)
                      SettingsTile(
                        icon: Icons.person_outline,
                        title: names[uid] ?? uid,
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl2),

            SectionHeader(
              title: const S('Recent activity', 'النشاط الأخير').of(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            ActivityTimeline(
              schoolId: schoolId,
              matches: (entry) =>
                  entry.studentId == student.id || entry.entityId == student.id,
            ),
          ],
        ),
      ),
    );
  }
}
