import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../../../app/notification_routing.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../notifications/presentation/notifications_inbox_page.dart';
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

/// The children tab, with a switcher above the list so a parent with more
/// than one child can put a single child on screen on their own.
///
/// "All children" stays the default and is always reachable: for a parent
/// of two, seeing both at once is genuinely the better view — that's the
/// whole question they opened the app to answer. The focused view earns its
/// place when there are three or four cards, or when one child's bus is the
/// only thing that matters right now, so it's offered rather than imposed.
/// Nothing is shared between the per-child views: each [ChildJourneyCard]
/// takes only its own [Student] and opens its own streams keyed by that
/// child's route and trip, so a sibling's boarding state or ETA can't leak
/// into another's.
class _ChildrenTab extends StatefulWidget {
  const _ChildrenTab({required this.user});

  final AppUser user;

  @override
  State<_ChildrenTab> createState() => _ChildrenTabState();
}

class _ChildrenTabState extends State<_ChildrenTab> {
  /// Null means "All children" — the default, matching how this tab has
  /// always behaved.
  String? _selectedStudentId;

  AppUser get user => widget.user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          S('Welcome, ${user.name}', 'أهلاً بيك، ${user.name}').of(context),
        ),
        actions: [_NotificationsBell(uid: user.uid)],
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
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: const [
                AppSkeletonListTile(),
                AppSkeletonListTile(),
                AppSkeletonListTile(),
              ],
            );
          }
          if (snapshot.hasError) {
            return ErrorStateView(
              message: const S(
                "Couldn't load your children — check your connection "
                    'and try again.',
                'معرفناش نحمّل بيانات أبنائك — اتأكد من الاتصال وجرب '
                    'تاني.',
              ).of(context),
            );
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return EmptyStateView(
              icon: Icons.family_restroom,
              title: const S(
                'No children linked yet',
                'مفيش أبناء مرتبطين لسه',
              ).of(context),
              message: const S(
                'Tap "Add child" below to add one — your school will '
                    'review and approve it.',
                'دوس على "إضافة طفل" تحت عشان تضيف واحد — مدرستك '
                    'هتراجعه وتوافق عليه.',
              ).of(context),
            );
          }

          final students = docs
              .map((doc) => Student.fromMap(doc.id, doc.data()))
              .toList();

          // A child unlinked (or still loading) while a filter was active
          // must not leave the tab showing nothing with no way back.
          final selectedId = students.any((s) => s.id == _selectedStudentId)
              ? _selectedStudentId
              : null;
          final visible = selectedId == null
              ? students
              : students.where((s) => s.id == selectedId).toList();

          return Column(
            children: [
              // One child means there is nothing to switch between.
              if (students.length > 1)
                _ChildSwitcher(
                  students: students,
                  selectedStudentId: selectedId,
                  onSelected: (id) => setState(() => _selectedStudentId = id),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    88,
                  ),
                  itemCount: visible.length + 1,
                  itemBuilder: (_, index) {
                    if (index == 0) {
                      return SectionHeader(
                        title: selectedId == null
                            ? const S('Your children', 'أبناؤك').of(context)
                            : visible.first.name,
                        subtitle: selectedId == null
                            ? S(
                                '${students.length} '
                                    '${students.length == 1 ? 'child' : 'children'} '
                                    'linked',
                                '${students.length} من الأبناء مرتبطين',
                              ).of(context)
                            : const S(
                                'Showing this child only',
                                'بنعرض الطفل ده بس',
                              ).of(context),
                      );
                    }
                    return ChildJourneyCard(
                      // Keyed by student id so switching filters rebuilds
                      // each card against its own child rather than
                      // recycling the element (and its stream
                      // subscriptions) from whichever sibling sat at that
                      // index before.
                      key: ValueKey(visible[index - 1].id),
                      user: user,
                      student: visible[index - 1],
                    );
                  },
                ),
              ),
            ],
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

/// A horizontal row of the parent's children, plus an "All" option — the
/// focus control for the tab below it. Scrollable rather than wrapped so a
/// parent of five children gets the same layout as a parent of two.
class _ChildSwitcher extends StatelessWidget {
  const _ChildSwitcher({
    required this.students,
    required this.selectedStudentId,
    required this.onSelected,
  });

  final List<Student> students;
  final String? selectedStudentId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
            child: ChoiceChip(
              label: Text(
                const S('All children', 'كل الأبناء').of(context),
              ),
              selected: selectedStudentId == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final student in students)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(student.name),
                selected: selectedStudentId == student.id,
                onSelected: (_) => onSelected(student.id),
              ),
            ),
        ],
      ),
    );
  }
}

/// The inbox entry point, with a live unread count. Reads the same
/// `users/{uid}/notifications` collection the inbox itself renders, so the
/// badge can never disagree with what's inside.
class _NotificationsBell extends StatelessWidget {
  const _NotificationsBell({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationsRepository().watchUnreadCount(uid),
      builder: (context, snapshot) {
        // An unavailable count is not worth an error state on the app bar
        // — the bell still opens the inbox, which has its own error state.
        final unread = snapshot.data ?? 0;
        return IconButton(
          tooltip: const S('Notifications', 'الإشعارات').of(context),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NotificationsInboxPage(uid: uid),
            ),
          ),
          icon: unread > 0
              ? Badge.count(
                  count: unread,
                  child: const Icon(Icons.notifications_outlined),
                )
              : const Icon(Icons.notifications_outlined),
        );
      },
    );
  }
}

