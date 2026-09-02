import 'dart:async';

import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../../driver_management/presentation/driver_detail_page.dart';
import '../../parents/presentation/parent_detail_page.dart';
import '../../students/presentation/student_detail_page.dart';
import '../../vehicles/presentation/vehicle_management_page.dart';
import '../data/global_search_repository.dart';

/// Admin global search (Feature: Global search) — one box, five
/// collections, real Firestore prefix queries (see
/// GlobalSearchRepository's own doc comment on how and why), landing on
/// the same unified detail pages the student/driver/parent directories
/// already open.
class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key, required this.schoolId});

  final String schoolId;

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final _controller = TextEditingController();
  final _repository = GlobalSearchRepository();
  Timer? _debounce;
  List<SearchResult>? _results;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = null;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    // A short debounce so typing "Ahmed" doesn't fire five separate
    // rounds of Firestore queries — one per keystroke — before the admin
    // finishes typing.
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    try {
      final results = await _repository.search(widget.schoolId, query);
      if (!mounted || _controller.text.trim() != query.trim()) return;
      setState(() {
        _results = results;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = const S(
          "Couldn't search right now — check your connection.",
          'معرفناش ندور دلوقتي — اتأكد من الاتصال.',
        ).of(context);
      });
    }
  }

  void _openResult(SearchResult result) {
    switch (result.kind) {
      case SearchResultKind.student:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentDetailPage(
              schoolId: widget.schoolId,
              studentId: result.id,
            ),
          ),
        );
      case SearchResultKind.parent:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ParentDetailPage(schoolId: widget.schoolId, uid: result.id),
          ),
        );
      case SearchResultKind.driver:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DriverDetailPage(
              schoolId: widget.schoolId,
              uid: result.id,
              displayName: result.title,
            ),
          ),
        );
      case SearchResultKind.bus:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VehicleManagementPage(
              schoolId: widget.schoolId,
              showAppBar: true,
            ),
          ),
        );
      case SearchResultKind.route:
        AppSnackbar.info(
          context,
          const S(
            'Manage routes from Operations → Routes.',
            'إدارة الخطوط من العمليات ← الخطوط.',
          ).of(context),
        );
    }
  }

  IconData _iconFor(SearchResultKind kind) => switch (kind) {
    SearchResultKind.student => Icons.school_outlined,
    SearchResultKind.parent => Icons.person_outline,
    SearchResultKind.driver => Icons.badge_outlined,
    SearchResultKind.bus => Icons.directions_bus_outlined,
    SearchResultKind.route => Icons.route_outlined,
  };

  String _kindLabel(BuildContext context, SearchResultKind kind) => switch (kind) {
    SearchResultKind.student => const S('Student', 'طالب').of(context),
    SearchResultKind.parent => const S('Parent', 'ولي أمر').of(context),
    SearchResultKind.driver => const S('Driver', 'سائق').of(context),
    SearchResultKind.bus => const S('Bus', 'أتوبيس').of(context),
    SearchResultKind.route => const S('Route', 'خط سير').of(context),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: const S(
              'Search students, parents, drivers, buses, routes…',
              'دور على طلاب، أولياء أمور، سائقين، أتوبيسات، خطوط…',
            ).of(context),
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
      ),
      body: Builder(
        builder: (context) {
          if (_controller.text.trim().isEmpty) {
            return EmptyStateView(
              icon: Icons.search,
              title: const S(
                'Search your whole school',
                'دور في مدرستك كلها',
              ).of(context),
              message: const S(
                'Matches names from the start — try the first few letters '
                    'of a student, parent, driver, bus or route.',
                'بيدور من أول الاسم — جرب أول كام حرف من اسم طالب أو ولي '
                    'أمر أو سائق أو أتوبيس أو خط.',
              ).of(context),
            );
          }
          if (_loading) {
            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: 5,
              itemBuilder: (_, _) => const AppSkeletonListTile(),
            );
          }
          if (_error != null) {
            return ErrorStateView(
              message: _error,
              onRetry: () => _search(_controller.text),
            );
          }
          final results = _results ?? const [];
          if (results.isEmpty) {
            return EmptyStateView(
              icon: Icons.search_off,
              title: const S('No matches', 'مفيش نتايج').of(context),
              message: const S(
                'Nothing starts with that — search matches from the '
                    'beginning of a name.',
                'مفيش حاجة بتبدأ بكده — البحث بيدور من أول الاسم.',
              ).of(context),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: results.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final result = results[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: colors.surfaceElevated,
                  child: Icon(_iconFor(result.kind), color: colors.textSecondary),
                ),
                title: Text(result.title),
                subtitle: Text(
                  result.subtitle == null
                      ? _kindLabel(context, result.kind)
                      : '${_kindLabel(context, result.kind)} · ${result.subtitle}',
                ),
                onTap: () => _openResult(result),
              );
            },
          );
        },
      ),
    );
  }
}
