import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../../app/notification_routing.dart';
import '../../community/presentation/community_page.dart';
import '../../messages/presentation/parent_requests_page.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../notifications/presentation/notifications_inbox_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../students/data/students_repository.dart';
import '../../trips/data/trips_repository.dart';
import 'child_journey_card.dart';
import 'child_switcher.dart';

/// Above this width the bottom bar becomes a side rail: on a desktop
/// browser a 68px bar pinned to the bottom of a 1400px window is a long way
/// from the content it navigates, and the shared theme already ships a
/// `navigationRailTheme` for exactly this.
const _railBreakpoint = 1000.0;

/// The widest the home content is allowed to get. Past this, extra width
/// goes to margins rather than to 1200px-long lines of text — except inside
/// a focused child's card, which spends it on the live map (see
/// `_twoPaneBreakpoint` in child_journey_card.dart).
const _maxContentWidth = 980.0;

/// The parent app shell.
///
/// **Four destinations: Home, Messages, Community, Profile.**
///
/// *Home* absorbs tracking rather than tracking getting a destination of
/// its own. There is exactly one trip per route per day in this system, so
/// a permanent "Tracking" tab would be an empty room for most of the
/// twenty-four hours — a nav item that is disabled or apologetic most of
/// the time trains people to stop looking at it, which is the opposite of
/// what a safety app wants. Instead the live map *becomes* the centerpiece
/// of Home the moment a bus is actually out for a child, and a full-screen
/// tracking page is one tap from there (see [LiveTripMapPage]) — offered
/// only when there is something live to open.
///
/// *Messages* is promoted out of Profile, where it used to sit as a
/// ListTile. It is the app's only two-way channel with the school: a parent
/// starts threads there and comes back for replies, and burying a
/// conversation two taps deep under "Profile" is the wrong shape for that.
///
/// *Community* (Feature: Parent Community) is the school's anonymous
/// parent feed — problems, questions, suggestions, feedback — kept as its
/// own destination rather than folded into Home, since it's a distinct
/// audience-wide space rather than anything about *this* parent's own
/// child.
///
/// *Notifications* deliberately stays as the app-bar bell with a live
/// unread badge instead of taking its own slot. It is a read-only history
/// — one that already announces itself through push and through the badge —
/// and a badge on a bell is exactly as discoverable as a nav item without
/// spending a permanent slot on a log.
class ParentHomePage extends StatefulWidget {
  const ParentHomePage({super.key, required this.user, required this.onSignOut});

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  static const _homeIndex = 0;
  static const _messagesIndex = 1;
  static const _communityIndex = 2;

  int _index = _homeIndex;

  @override
  void initState() {
    super.initState();
    NotificationRouting.pendingTarget.addListener(_onNotificationTapped);
    _onNotificationTapped();
  }

  @override
  void dispose() {
    NotificationRouting.pendingTarget.removeListener(_onNotificationTapped);
    super.dispose();
  }

  /// Sends a tapped push to the destination that actually holds it. The
  /// `type` strings are the ones functions/src/index.ts really sends —
  /// message traffic (including an admin's "Message Parent" reply to a
  /// community post, which reuses the exact same parent_message pipeline)
  /// belongs on Messages; a community moderation notice (post hidden,
  /// report resolved — Feature: Parent Community) belongs on Community;
  /// everything else (trip, emergency, boarding, deviation, bus change) is
  /// about a child's journey, which lives on Home.
  void _onNotificationTapped() {
    final type = NotificationRouting.pendingTarget.value;
    if (type == null) return;
    NotificationRouting.pendingTarget.value = null;
    final target = switch (type) {
      'school_message' || 'parent_message' => _messagesIndex,
      'community_post_hidden' ||
      'community_report_resolved' ||
      'community_admin_replied' =>
        _communityIndex,
      _ => _homeIndex,
    };
    setState(() => _index = target);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(user: widget.user),
      ParentRequestsPage(user: widget.user),
      CommunityPage(user: widget.user),
      ProfilePage(user: widget.user, onSignOut: widget.onSignOut),
    ];

    final destinations = <_Destination>[
      _Destination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: const S(
          'Home',
          'الرئيسية',
          fr: 'Accueil',
          es: 'Inicio',
        ).of(context),
      ),
      _Destination(
        icon: Icons.chat_bubble_outline_rounded,
        selectedIcon: Icons.chat_bubble_rounded,
        label: const S(
          'Messages',
          'الرسايل',
          fr: 'Messages',
          es: 'Mensajes',
        ).of(context),
      ),
      _Destination(
        icon: Icons.forum_outlined,
        selectedIcon: Icons.forum_rounded,
        label: const S(
          'Community',
          'المجتمع',
          fr: 'Communauté',
          es: 'Comunidad',
        ).of(context),
      ),
      _Destination(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: const S(
          'Profile',
          'حسابي',
          fr: 'Profil',
          es: 'Perfil',
        ).of(context),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final body = IndexedStack(index: _index, children: pages);
        if (constraints.maxWidth < _railBreakpoint) {
          return Scaffold(
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: [
                for (final destination in destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final destination in destinations)
                    NavigationRailDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: Text(destination.label),
                    ),
                ],
              ),
              VerticalDivider(width: 1, color: context.appColors.border),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}

/// One destination, described once and rendered by both the bar and the
/// rail so the two can't drift apart.
class _Destination {
  const _Destination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The home tab: who you are, which child you're looking at, and what is
/// happening to them right now.
///
/// The switcher's "All children" default stays: for a parent of two, seeing
/// both at once is genuinely the better answer. Selecting one child swaps
/// the whole tab into that child's full view — including the live map, if a
/// bus is out for them — and every card in the "all" view carries its own
/// way into that focused view, so choosing to see everything never means
/// losing access to the detail.
class _HomeTab extends StatefulWidget {
  const _HomeTab({required this.user});

  final AppUser user;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  /// Null means "All children" — the default.
  String? _selectedStudentId;

  AppUser get user => widget.user;

  // Created once for the lifetime of this State rather than inline in
  // build() — the enclosing AuthPage rebuilds ParentHomePage on every
  // AuthCubit emission (including redundant re-emissions of the same
  // signed-in state), and a fresh `.snapshots()` stream on each of those
  // rebuilds would make StreamBuilder tear down and resubscribe, which
  // resets it to ConnectionState.waiting — flashing the loading skeleton
  // back over already-loaded content every time.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _studentsStream =
      TripsRepository().watchMyStudents(
        schoolId: user.schoolId,
        parentUid: user.uid,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_greeting(context)),
        actions: [
          _NotificationsBell(uid: user.uid),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // The shell keeps every destination mounted at once (IndexedStack),
        // so Home's FAB and Messages' FAB exist in the tree simultaneously
        // — without distinct tags they collide on Flutter's default shared
        // Hero tag and throw "multiple heroes share the same tag".
        heroTag: 'home-add-child-fab',
        onPressed: () => _addChild(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(
          const S(
            'Add child',
            'إضافة طفل',
            fr: 'Ajouter un enfant',
            es: 'Agregar niño',
          ).of(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _studentsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _centered(
              ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: const [
                  AppSkeleton(width: 220, height: 18),
                  SizedBox(height: AppSpacing.xl),
                  AppSkeletonListTile(),
                  AppSkeletonListTile(),
                  AppSkeletonListTile(),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return ErrorStateView(
              message: const S(
                "Couldn't load your children — check your connection "
                    'and try again.',
                'معرفناش نحمّل بيانات أبنائك — اتأكد من الاتصال وجرب '
                    'تاني.',
                fr:
                    'Impossible de charger vos enfants — vérifiez votre '
                    'connexion et réessayez.',
                es:
                    'No se pudieron cargar sus hijos: revise su conexión '
                    'e inténtelo de nuevo.',
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
                fr: "Aucun enfant lié pour l'instant",
                es: 'Aún no hay niños vinculados',
              ).of(context),
              message: const S(
                'Tap "Add child" below to add one — your school will '
                    'review and approve it.',
                'دوس على "إضافة طفل" تحت عشان تضيف واحد — مدرستك '
                    'هتراجعه وتوافق عليه.',
                fr:
                    'Appuyez sur « Ajouter un enfant » ci-dessous pour en '
                    "ajouter un — votre école l'examinera et l'approuvera.",
                es:
                    'Toque "Agregar niño" abajo para añadir uno: su '
                    'escuela lo revisará y aprobará.',
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

          // One child is always their own focus — there is nothing to
          // switch between, and no reason to make them tap to see the map.
          final focused = students.length == 1 ? students.single.id : selectedId;
          final visible = focused == null
              ? students
              : students.where((s) => s.id == focused).toList();

          return _centered(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (students.length > 1)
                  ChildSwitcher(
                    students: students,
                    selectedStudentId: selectedId,
                    onSelected: (id) =>
                        setState(() => _selectedStudentId = id),
                  ),
                Expanded(
                  // Reserves real layout space for the floating "Add child"
                  // FAB by shrinking the ListView's own viewport, rather
                  // than relying on the ListView's trailing scroll padding.
                  // Trailing padding only helps once the user has scrolled
                  // to the very end — on a page short enough to render
                  // fully without scrolling (e.g. a single focused child),
                  // the last row (Message school / Child settings) is laid
                  // out from the top and can land at the same on-screen
                  // position the FAB floats over, regardless of how much
                  // padding follows off-screen. Shrinking the viewport up
                  // front keeps content out of that zone in every case.
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 88),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      children: [
                        _TodayStrip(
                          childCount: students.length,
                          focusedName: focused == null
                              ? null
                              : visible.first.name,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        for (final student in visible)
                          ChildJourneyCard(
                            // Keyed by student id so switching filters
                            // rebuilds each card against its own child
                            // rather than recycling the element (and its
                            // stream subscriptions) from whichever sibling
                            // sat at that index before.
                            key: ValueKey('${student.id}|${focused != null}'),
                            user: user,
                            student: student,
                            expanded: focused != null,
                            onFocusRequested: focused != null
                                ? null
                                : () => setState(
                                    () => _selectedStudentId = student.id,
                                  ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Keeps a desktop browser from stretching the content to the full window
  /// width, without changing anything about the narrow layout.
  Widget _centered(Widget child) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxContentWidth),
      child: child,
    ),
  );

  /// Time of day comes from the device clock — the one thing here that
  /// isn't read from Firestore, and the only thing it's used for is how to
  /// say hello.
  String _greeting(BuildContext context) {
    final hour = DateTime.now().hour;
    final name = user.name;
    if (hour < 12) {
      return S(
        'Good morning, $name',
        'صباح الخير يا $name',
        fr: 'Bonjour, $name',
        es: 'Buenos días, $name',
      ).of(context);
    }
    if (hour < 17) {
      return S(
        'Good afternoon, $name',
        'مساء الخير يا $name',
        fr: 'Bon après-midi, $name',
        es: 'Buenas tardes, $name',
      ).of(context);
    }
    return S(
      'Good evening, $name',
      'مساء الخير يا $name',
      fr: 'Bonsoir, $name',
      es: 'Buenas noches, $name',
    ).of(context);
  }

  Future<void> _addChild(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          const S(
            'Add child',
            'إضافة طفل',
            fr: 'Ajouter un enfant',
            es: 'Agregar niño',
          ).of(dialogContext),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: const S(
              "Child's name",
              'اسم الطفل',
              fr: "Nom de l'enfant",
              es: 'Nombre del niño',
            ).of(dialogContext),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              const S(
                'Cancel',
                'إلغاء',
                fr: 'Annuler',
                es: 'Cancelar',
              ).of(dialogContext),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(
              const S('Add', 'إضافة', fr: 'Ajouter', es: 'Agregar').of(
                dialogContext,
              ),
            ),
          ),
        ],
      ),
    );
    // Deliberately not disposed here: the dialog's own TextField is still
    // mounted and mid-exit-transition when this Future resolves (showDialog
    // completes as soon as Navigator.pop is called, before the reverse
    // animation finishes), so an immediate dispose() crashes with "A
    // TextEditingController was used after being disposed" the next time
    // that still-animating TextField rebuilds. A short-lived, unowned
    // controller with no other resources is safe to just let the GC
    // collect once this closure returns.
    if (name == null || name.trim().isEmpty) return;
    await StudentsRepository().addChild(
      schoolId: user.schoolId,
      parentUid: user.uid,
      name: name,
    );
  }
}

/// The one line of context above the cards: today's date, and either how
/// many children are linked or which one is currently in focus. Both are
/// facts already on screen elsewhere — this is orientation, not new data,
/// which is why it stays one muted line rather than a hero panel.
class _TodayStrip extends StatelessWidget {
  const _TodayStrip({required this.childCount, required this.focusedName});

  final int childCount;
  final String? focusedName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final name = focusedName;

    return Row(
      children: [
        Icon(Icons.calendar_today_rounded, size: 14, color: colors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            DateFormat.MMMMEEEEd().format(DateTime.now()),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          name != null
              ? S(
                  'Showing $name',
                  'بنعرض $name',
                  fr: 'Affichage de $name',
                  es: 'Mostrando a $name',
                ).of(context)
              : S(
                  '$childCount ${childCount == 1 ? 'child' : 'children'}',
                  '$childCount من الأبناء',
                  fr: '$childCount ${childCount == 1 ? 'enfant' : 'enfants'}',
                  es: '$childCount ${childCount == 1 ? 'niño' : 'niños'}',
                ).of(context),
          style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
        ),
      ],
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
          tooltip: const S(
            'Notifications',
            'الإشعارات',
            fr: 'Notifications',
            es: 'Notificaciones',
          ).of(context),
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
