import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../../../widgets/activity_timeline.dart';
import '../../common/presentation/domain_labels.dart';

/// A unified parent profile/detail view (Feature: unified profile/detail
/// system). A parent's own account data lives in `users/{uid}` (name,
/// phone, email, notification prefs) — but firestore.rules only grants
/// that read to the user themselves or a system admin (`allow read: if
/// isSelf(uid) || isSystemAdmin();`), not a school admin, so none of that
/// is readable from here. What a school admin *can* read is the
/// `members/{uid}` doc this page is actually built from (name, status)
/// plus the student roster to find this parent's children — genuinely
/// everything currently exposed to this role, not an oversight.
class ParentDetailPage extends StatelessWidget {
  const ParentDetailPage({super.key, required this.schoolId, required this.uid});

  final String schoolId;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          const S(
            'Parent',
            'ولي الأمر',
            fr: 'Parent',
            es: 'Familiar',
          ).of(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('members')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const ErrorStateView();
          if (!snapshot.hasData) {
            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.xl),
              itemCount: 4,
              itemBuilder: (_, _) => const AppSkeletonListTile(),
            );
          }
          final data = snapshot.data!.data();
          if (data == null) {
            return EmptyStateView(
              icon: Icons.person_off_outlined,
              title: const S(
                'This parent is no longer in your school.',
                'ولي الأمر ده مبقاش في مدرستك.',
                fr: 'Ce parent ne fait plus partie de votre école.',
                es: 'Este familiar ya no pertenece a tu colegio.',
              ).of(context),
            );
          }
          final name = data['displayName']?.toString() ?? uid;
          final status = data['status']?.toString() ?? 'pending';
          return _ParentDetailBody(
            schoolId: schoolId,
            uid: uid,
            name: name,
            status: status,
          );
        },
      ),
    );
  }
}

class _ParentDetailBody extends StatelessWidget {
  const _ParentDetailBody({
    required this.schoolId,
    required this.uid,
    required this.name,
    required this.status,
  });

  final String schoolId;
  final String uid;
  final String name;
  final String status;

  @override
  Widget build(BuildContext context) {
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
                InitialAvatar(name: name, size: 56),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(name, style: Theme.of(context).textTheme.titleLarge),
                ),
                StatusBadge(
                  label: memberStatusLabel(context, status),
                  tone: memberStatusTone(status),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl2),

            SectionHeader(
              title: const S(
                'Children',
                'الأبناء',
                fr: 'Enfants',
                es: 'Hijos',
              ).of(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('schools')
                  .doc(schoolId)
                  .collection('students')
                  .where('parentIds', arrayContains: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                final children = (snapshot.data?.docs ?? const [])
                    .map((doc) => Student.fromMap(doc.id, doc.data()))
                    .toList();
                if (children.isEmpty) {
                  return EmptyStateView(
                    compact: true,
                    icon: Icons.family_restroom_outlined,
                    title: const S(
                      'No children linked yet',
                      'مفيش أبناء مرتبطين لسه',
                      fr: 'Aucun enfant lié pour le moment',
                      es: 'Aún no hay hijos vinculados',
                    ).of(context),
                  );
                }
                return AppListCard(
                  children: [
                    for (final child in children)
                      SettingsTile(
                        icon: Icons.child_care_outlined,
                        title: child.name,
                        subtitle: !child.approved
                            ? const S(
                                'Awaiting approval',
                                'في انتظار الموافقة',
                                fr: "En attente d'approbation",
                                es: 'Pendiente de aprobación',
                              ).of(context)
                            : child.isAbsentToday
                            ? const S(
                                'Absent today',
                                'غايب النهاردة',
                                fr: "Absent aujourd'hui",
                                es: 'Ausente hoy',
                              ).of(context)
                            : const S(
                                'Active',
                                'نشط',
                                fr: 'Actif',
                                es: 'Activo',
                              ).of(context),
                        trailing: StatusBadge(
                          label: !child.approved
                              ? const S(
                                  'Pending',
                                  'قيد الانتظار',
                                  fr: 'En attente',
                                  es: 'Pendiente',
                                ).of(context)
                              : child.isAbsentToday
                              ? const S(
                                  'Absent',
                                  'غايب',
                                  fr: 'Absent',
                                  es: 'Ausente',
                                ).of(context)
                              : const S(
                                  'Active',
                                  'نشط',
                                  fr: 'Actif',
                                  es: 'Activo',
                                ).of(context),
                          tone: !child.approved
                              ? StatusTone.warning
                              : child.isAbsentToday
                              ? StatusTone.warning
                              : StatusTone.success,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl2),

            SectionHeader(
              title: const S(
                'Recent activity',
                'النشاط الأخير',
                fr: 'Activité récente',
                es: 'Actividad reciente',
              ).of(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            ActivityTimeline(
              schoolId: schoolId,
              matches: (entry) => entry.actorUid == uid,
            ),
          ],
        ),
      ),
    );
  }
}
