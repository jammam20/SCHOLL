import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../../profile/presentation/profile_page.dart';
import '../../../widgets/async_error_view.dart';
import '../data/super_admin_repository.dart';

/// The Super Admin's control tower: create new schools (each gets a join
/// code the school's owner uses to self-register as its first admin — no
/// Firebase Console needed), and approve those first-admin requests.
class SuperAdminHomePage extends StatefulWidget {
  const SuperAdminHomePage({
    super.key,
    required this.name,
    required this.onSignOut,
  });

  final String name;
  final VoidCallback onSignOut;

  @override
  State<SuperAdminHomePage> createState() => _SuperAdminHomePageState();
}

class _SuperAdminHomePageState extends State<SuperAdminHomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DashboardTab(name: widget.name),
      const _SchoolsTab(),
      const _PendingAdminsTab(),
      ProfilePage(name: widget.name, onSignOut: widget.onSignOut),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: const S('Dashboard', 'الرئيسية').of(context),
          ),
          NavigationDestination(
            icon: const Icon(Icons.school_outlined),
            selectedIcon: const Icon(Icons.school),
            label: const S('Schools', 'المدارس').of(context),
          ),
          NavigationDestination(
            icon: const Icon(Icons.pending_actions_outlined),
            selectedIcon: const Icon(Icons.pending_actions),
            label: const S('Requests', 'الطلبات').of(context),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: const S('Profile', 'حسابي').of(context),
          ),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(const S('Dashboard', 'الرئيسية').of(context)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: SuperAdminRepository().watchSchools(),
        builder: (context, schoolsSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: SuperAdminRepository().watchPendingAdmins(),
            builder: (context, pendingSnapshot) {
              if (schoolsSnapshot.hasError || pendingSnapshot.hasError) {
                return const AsyncErrorView();
              }

              final isLoading =
                  !schoolsSnapshot.hasData && !pendingSnapshot.hasData;

              final schools = schoolsSnapshot.data?.docs ?? const [];
              final activeSchools = schools
                  .where((doc) => doc.data()['isActive'] == true)
                  .length;
              final pendingCount = pendingSnapshot.data?.docs.length ?? 0;

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.xl2),
                children: [
                  Text(
                    S('Welcome, $name', 'أهلاً بيك، $name').of(context),
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.appColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    const S(
                      "Here's your platform at a glance.",
                      'دي نظرة عامة على المنصة.',
                    ).of(context),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl2),
                  if (isLoading)
                    const _MetricsSkeletonRow()
                  else
                    IntrinsicHeight(
                      child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: MetricStatCard(
                            icon: Icons.school_outlined,
                            label: const S(
                              'Total schools',
                              'إجمالي المدارس',
                            ).of(context),
                            value: '${schools.length}',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: MetricStatCard(
                            icon: Icons.check_circle_outline,
                            label: const S(
                              'Active schools',
                              'مدارس نشطة',
                            ).of(context),
                            value: '$activeSchools',
                            tone: context.appColors.success,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: MetricStatCard(
                            icon: Icons.pending_actions_outlined,
                            label: const S(
                              'Pending requests',
                              'طلبات معلّقة',
                            ).of(context),
                            value: '$pendingCount',
                            tone: context.appColors.warning,
                          ),
                        ),
                      ],
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// A loading placeholder shaped like the metrics row above, shown while
/// both dashboard streams are producing their first snapshot.
class _MetricsSkeletonRow extends StatelessWidget {
  const _MetricsSkeletonRow();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    Widget card() => Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: colors.border),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSkeleton(width: 70, height: 12),
            SizedBox(height: 12),
            AppSkeleton(width: 40, height: 22),
          ],
        ),
      ),
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          card(),
          const SizedBox(width: AppSpacing.md),
          card(),
          const SizedBox(width: AppSpacing.md),
          card(),
        ],
      ),
    );
  }
}

class _SchoolsTab extends StatelessWidget {
  const _SchoolsTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(const S('Schools', 'المدارس').of(context))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createSchool(context),
        icon: const Icon(Icons.add),
        label: Text(const S('School', 'مدرسة').of(context)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: SuperAdminRepository().watchSchools(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const AsyncErrorView();

          if (!snapshot.hasData) {
            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: 4,
              itemBuilder: (_, _) => const AppSkeletonListTile(),
            );
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return EmptyStateView(
              icon: Icons.school_outlined,
              title: const S('No schools yet.', 'مفيش مدارس لسه.').of(
                context,
              ),
              message: const S(
                'Add your first school to give it a join code.',
                'ضيف أول مدرسة عشان تاخد كود انضمام.',
              ).of(context),
              actionLabel: const S('Add school', 'إضافة مدرسة').of(context),
              onAction: () => _createSchool(context),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: docs.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, index) {
              final doc = docs[index];
              final data = doc.data();
              final isActive = data['isActive'] == true;
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
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (isActive ? colors.success : colors.textMuted)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        Icons.school,
                        color: isActive ? colors.success : colors.textMuted,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['name']?.toString() ?? '',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: colors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.qr_code_2_outlined,
                                size: 14,
                                color: colors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${data['code'] ?? '-'}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: colors.textMuted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusBadge(
                          label: isActive
                              ? const S('Active', 'نشطة').of(context)
                              : const S('Inactive', 'غير نشطة').of(context),
                          tone: isActive
                              ? StatusTone.success
                              : StatusTone.neutral,
                        ),
                        Switch(
                          value: isActive,
                          onChanged: (value) => SuperAdminRepository()
                              .setSchoolActive(
                                schoolId: doc.id,
                                active: value,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createSchool(BuildContext context) async {
    final name = TextEditingController();
    final code = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(const S('Add school', 'إضافة مدرسة').of(dialogContext)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(
                labelText: const S(
                  'School name',
                  'اسم المدرسة',
                ).of(dialogContext),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: code,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: const S(
                  'Join code',
                  'كود الانضمام',
                ).of(dialogContext),
                helperText: const S(
                  "The school's owner uses this to self-register.",
                  'صاحب المدرسة هيستخدم الكود ده عشان يسجل نفسه.',
                ).of(dialogContext),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(const S('Cancel', 'إلغاء').of(dialogContext)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(const S('Create', 'إنشاء').of(dialogContext)),
          ),
        ],
      ),
    );

    if (result == true &&
        name.text.trim().isNotEmpty &&
        code.text.trim().isNotEmpty) {
      try {
        await SuperAdminRepository().createSchool(
          name: name.text,
          code: code.text,
        );
        if (context.mounted) {
          AppSnackbar.success(
            context,
            const S('School created.', 'اتعملت المدرسة.').of(context),
          );
        }
      } on SchoolCodeTakenException catch (error) {
        if (context.mounted) {
          AppSnackbar.error(
            context,
            S(
              'Join code "${error.code}" is already used by another school '
                  '— pick a different one.',
              'كود الانضمام "${error.code}" مستخدم بالفعل لمدرسة تانية — '
                  'اختار كود مختلف.',
            ).of(context),
          );
        }
      } catch (_) {
        if (context.mounted) {
          AppSnackbar.error(
            context,
            const S("Couldn't create the school — try again.", 'معرفناش نعمل المدرسة — جرب تاني.')
                .of(context),
          );
        }
      }
    }

    // Deliberately not disposed here: the dialog's own TextFields are still
    // mounted and mid-exit-transition when this Future resolves (showDialog
    // completes as soon as Navigator.pop is called, before the reverse
    // animation finishes), so an immediate dispose() crashes with "A
    // TextEditingController was used after being disposed" the next time
    // those still-animating TextFields rebuild. Short-lived, unowned
    // controllers with no other resources are safe to just let the GC
    // collect once this closure returns.
  }
}

class _PendingAdminsTab extends StatelessWidget {
  const _PendingAdminsTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(const S('Pending Admins', 'طلبات الأدمن').of(context)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: SuperAdminRepository().watchPendingAdmins(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const AsyncErrorView();

          if (!snapshot.hasData) {
            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: 4,
              itemBuilder: (_, _) => const AppSkeletonListTile(),
            );
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return EmptyStateView(
              icon: Icons.pending_actions_outlined,
              title: const S(
                'No pending admin requests.',
                'مفيش طلبات أدمن معلّقة.',
              ).of(context),
              message: const S(
                "New requests from a school's first admin will show up here.",
                'الطلبات الجديدة من أول أدمن للمدرسة هتظهر هنا.',
              ).of(context),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: docs.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, index) {
              final doc = docs[index];
              final data = doc.data();
              // Collection-group docs: reference.parent.parent is the school.
              final schoolId = doc.reference.parent.parent!.id;

              return _PendingAdminCard(
                schoolId: schoolId,
                uid: doc.id,
                displayName: data['displayName']?.toString() ?? doc.id,
                email: '${data['email'] ?? ''}',
              );
            },
          );
        },
      ),
    );
  }
}

class _PendingAdminCard extends StatefulWidget {
  const _PendingAdminCard({
    required this.schoolId,
    required this.uid,
    required this.displayName,
    required this.email,
  });

  final String schoolId;
  final String uid;
  final String displayName;
  final String email;

  @override
  State<_PendingAdminCard> createState() => _PendingAdminCardState();
}

class _PendingAdminCardState extends State<_PendingAdminCard> {
  bool _busy = false;

  Future<void> _approve() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: const S('Approve this admin?', 'الموافقة على الأدمن ده؟').of(
        context,
      ),
      message: S(
        '${widget.displayName} will get full admin access to their school.',
        '${widget.displayName} هياخد صلاحيات أدمن كاملة على مدرسته.',
      ).of(context),
      confirmLabel: const S('Approve', 'موافقة').of(context),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await SuperAdminRepository().approveAdmin(
        schoolId: widget.schoolId,
        uid: widget.uid,
      );
      if (!mounted) return;
      AppSnackbar.success(
        context,
        const S('Admin approved.', 'تمت الموافقة على الأدمن.').of(context),
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(
        context,
        const S("Couldn't approve — try again.", 'معرفناش نوافق — جرب تاني.')
            .of(context),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reasonController = TextEditingController();
    final confirmed = await showAppConfirmDialog(
      context,
      title: const S('Reject this admin?', 'رفض الأدمن ده؟').of(context),
      message: S(
        '${widget.displayName} will not be able to sign in.',
        '${widget.displayName} مش هيقدر يسجّل دخول.',
      ).of(context),
      confirmLabel: const S('Reject', 'رفض').of(context),
      destructive: true,
      reasonController: reasonController,
      reasonHint: const S(
        'Reason (shown to the applicant)',
        'السبب (بيتشاف لصاحب الطلب)',
      ).of(context),
    );
    // Deliberately not disposed here: the dialog's own TextField is still
    // mounted and mid-exit-transition when this Future resolves (showDialog
    // completes as soon as Navigator.pop is called, before the reverse
    // animation finishes) — see pending_approval_card.dart's identical note.
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await SuperAdminRepository().rejectAdmin(
        schoolId: widget.schoolId,
        uid: widget.uid,
        reason: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim(),
      );
      if (!mounted) return;
      AppSnackbar.success(
        context,
        const S('Admin rejected.', 'تم رفض الأدمن.').of(context),
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(
        context,
        const S("Couldn't reject — try again.", 'معرفناش نرفض — جرب تاني.')
            .of(context),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.hourglass_top_rounded,
              color: colors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.displayName,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(color: colors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    StatusBadge(
                      label: const S('Pending', 'معلّق').of(context),
                      tone: StatusTone.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance
                      .collection('schools')
                      .doc(widget.schoolId)
                      .get(),
                  builder: (context, schoolSnapshot) {
                    final schoolName =
                        schoolSnapshot.data?.data()?['name']?.toString() ??
                        widget.schoolId;
                    return Text(
                      S('School: $schoolName', 'المدرسة: $schoolName').of(
                        context,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filled(
                  tooltip: const S('Approve', 'موافقة').of(context),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.success.withValues(alpha: 0.12),
                    foregroundColor: colors.success,
                  ),
                  icon: const Icon(Icons.check_rounded),
                  onPressed: _approve,
                ),
                const SizedBox(height: AppSpacing.xs),
                IconButton.filled(
                  tooltip: const S('Reject', 'رفض').of(context),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.error.withValues(alpha: 0.12),
                    foregroundColor: colors.error,
                  ),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _reject,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
