import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../app/app_settings.dart';
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

              final schools = schoolsSnapshot.data?.docs ?? const [];
              final activeSchools = schools
                  .where((doc) => doc.data()['isActive'] == true)
                  .length;
              final pendingCount = pendingSnapshot.data?.docs.length ?? 0;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    S('Welcome, $name', 'أهلاً بيك، $name').of(context),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.school,
                          label: const S('Total schools', 'إجمالي المدارس').of(context),
                          value: '${schools.length}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.check_circle_outline,
                          label: const S('Active schools', 'مدارس نشطة').of(context),
                          value: '$activeSchools',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _StatCard(
                    icon: Icons.pending_actions,
                    label: const S(
                      'Pending admin requests',
                      'طلبات أدمن معلّقة',
                    ).of(context),
                    value: '$pendingCount',
                    fullWidth: true,
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: Icon(icon, size: 20),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
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

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return Center(
              child: Text(const S('No schools yet.', 'مفيش مدارس لسه.').of(context)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (_, index) {
              final doc = docs[index];
              final data = doc.data();
              final isActive = data['isActive'] == true;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.15),
                    child: const Icon(Icons.school),
                  ),
                  title: Text(data['name']?.toString() ?? ''),
                  subtitle: Text('Code: ${data['code'] ?? '-'}'),
                  trailing: Switch(
                    value: isActive,
                    onChanged: (value) => SuperAdminRepository()
                        .setSchoolActive(schoolId: doc.id, active: value),
                  ),
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
            TextField(
              controller: code,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: const S('Join code', 'كود الانضمام').of(dialogContext),
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
      await SuperAdminRepository().createSchool(
        name: name.text,
        code: code.text,
      );
    }

    name.dispose();
    code.dispose();
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

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return Center(
              child: Text(
                const S(
                  'No pending admin requests.',
                  'مفيش طلبات أدمن معلّقة.',
                ).of(context),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (_, index) {
              final doc = docs[index];
              final data = doc.data();
              // Collection-group docs: reference.parent.parent is the school.
              final schoolId = doc.reference.parent.parent!.id;

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.hourglass_top)),
                  title: Text(data['displayName']?.toString() ?? doc.id),
                  subtitle: Text(
                    '${data['email'] ?? ''} · school: $schoolId',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: const S('Approve', 'موافقة').of(context),
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => SuperAdminRepository().approveAdmin(
                          schoolId: schoolId,
                          uid: doc.id,
                        ),
                      ),
                      IconButton(
                        tooltip: const S('Reject', 'رفض').of(context),
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () => SuperAdminRepository().rejectAdmin(
                          schoolId: schoolId,
                          uid: doc.id,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
