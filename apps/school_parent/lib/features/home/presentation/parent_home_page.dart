import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../../../app/notification_routing.dart';
import '../../profile/presentation/profile_page.dart';
import '../../students/data/students_repository.dart';
import '../../trips/data/trips_repository.dart';
import 'child_journey_card.dart';

class ParentHomePage extends StatefulWidget {
  const ParentHomePage({super.key, required this.user, required this.onSignOut});

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Every notification this app receives (trip status or emergency) is
    // about a child's trip — that lives on the Children tab.
    NotificationRouting.pendingTarget.addListener(_onNotificationTapped);
    _onNotificationTapped();
  }

  @override
  void dispose() {
    NotificationRouting.pendingTarget.removeListener(_onNotificationTapped);
    super.dispose();
  }

  void _onNotificationTapped() {
    if (NotificationRouting.pendingTarget.value == null) return;
    NotificationRouting.pendingTarget.value = null;
    setState(() => _index = 0);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _ChildrenTab(user: widget.user),
      ProfilePage(user: widget.user, onSignOut: widget.onSignOut),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.family_restroom_outlined),
            selectedIcon: const Icon(Icons.family_restroom),
            label: const S('Children', 'الأبناء').of(context),
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

class _ChildrenTab extends StatelessWidget {
  const _ChildrenTab({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          S('Welcome, ${user.name}', 'أهلاً بيك، ${user.name}').of(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addChild(context),
        icon: const Icon(Icons.add),
        label: Text(const S('Add child', 'إضافة طفل').of(context)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: TripsRepository().watchMyStudents(
          schoolId: user.schoolId,
          parentUid: user.uid,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  const S(
                    "Couldn't load your children — check your connection "
                        'and try again.',
                    'معرفناش نحمّل بيانات أبنائك — اتأكد من الاتصال وجرب '
                        'تاني.',
                  ).of(context),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.family_restroom,
                      size: 56,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      const S('No children linked yet', 'مفيش أبناء مرتبطين لسه').of(
                        context,
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      const S(
                        'Tap "Add child" below to add one — your school will '
                            'review and approve it.',
                        'دوس على "إضافة طفل" تحت عشان تضيف واحد — مدرستك '
                            'هتراجعه وتوافق عليه.',
                      ).of(context),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final students = docs
              .map((doc) => Student.fromMap(doc.id, doc.data()))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: students.length,
            itemBuilder: (_, index) => ChildJourneyCard(
              schoolId: user.schoolId,
              student: students[index],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addChild(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(const S('Add child', 'إضافة طفل').of(dialogContext)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: const S("Child's name", 'اسم الطفل').of(dialogContext),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(const S('Cancel', 'إلغاء').of(dialogContext)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(const S('Add', 'إضافة').of(dialogContext)),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name == null || name.trim().isEmpty) return;
    await StudentsRepository().addChild(
      schoolId: user.schoolId,
      parentUid: user.uid,
      name: name,
    );
  }
}

