import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../data/community_repository.dart';
import 'community_category_ui.dart';
import 'community_post_card.dart';
import 'post_composer_page.dart';
import 'post_detail_page.dart';

/// The school community feed (Feature: Parent Community) — every post here
/// is anonymous to other parents; see [CommunityPostCard] and
/// [CommunityRepository] for how that's enforced end to end, not just in
/// this screen's own rendering.
class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key, required this.user});

  final AppUser user;

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final _repository = CommunityRepository();
  CommunityPostCategory? _categoryFilter;
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openComposer() async {
    final posted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PostComposerPage(
          schoolId: widget.user.schoolId,
          parentUid: widget.user.uid,
        ),
      ),
    );
    if (posted == true && mounted) {
      AppSnackbar.success(
        context,
        const S('Posted to your school community.', 'اتنشر في مجتمع المدرسة.')
            .of(context),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: Text(const S('Community', 'مجتمع المدرسة').of(context)),
        actions: [
          IconButton(
            tooltip: const S('Search', 'بحث').of(context),
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _searchController.clear();
            }),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Column(
            children: [
              if (_searching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintText: const S(
                        'Search posts…',
                        'دور في المنشورات…',
                      ).of(context),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    children: [
                      _FilterChip(
                        label: const S('All', 'الكل').of(context),
                        selected: _categoryFilter == null,
                        onTap: () => setState(() => _categoryFilter = null),
                      ),
                      for (final category in CommunityPostCategory.values)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          child: _FilterChip(
                            label:
                                '${CommunityCategoryUi.of(category).emoji} '
                                '${CommunityCategoryUi.of(category).label(context)}',
                            selected: _categoryFilter == category,
                            onTap: () =>
                                setState(() => _categoryFilter = category),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'community-new-post-fab',
        onPressed: _openComposer,
        icon: const Icon(Icons.add_comment_outlined),
        label: Text(const S('New post', 'منشور جديد').of(context)),
      ),
      body: StreamBuilder<List<CommunityPost>>(
        stream: _repository.watchFeed(
          schoolId: widget.user.schoolId,
          category: _categoryFilter,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: 4,
              itemBuilder: (_, index) =>
                  Padding(
                    key: ValueKey('skeleton-$index'),
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: const AppSkeletonListTile(),
                  ),
            );
          }
          if (snapshot.hasError) {
            return ErrorStateView(
              message: const S(
                "Couldn't load the community feed — check your connection "
                    'and try again.',
                'معرفناش نحمّل مجتمع المدرسة — اتأكد من الاتصال وجرب تاني.',
              ).of(context),
              onRetry: () => setState(() {}),
            );
          }

          var posts = snapshot.data ?? const <CommunityPost>[];
          final query = _searchController.text.trim().toLowerCase();
          if (_searching && query.isNotEmpty) {
            posts = posts
                .where((post) => post.content.toLowerCase().contains(query))
                .toList();
          }

          if (posts.isEmpty) {
            return EmptyStateView(
              icon: Icons.forum_outlined,
              title: const S(
                'No posts in the school community yet',
                'لسه مفيش منشورات في مجتمع المدرسة',
              ).of(context),
              message: const S(
                'Be the first to share a problem, a question, or a '
                    'suggestion — your identity stays anonymous to other '
                    'parents.',
                'كن أول واحد يشارك مشكلة أو سؤال أو اقتراح — هويتك هتفضل '
                    'مجهولة لباقي أولياء الأمور.',
              ).of(context),
              actionLabel: const S('New post', 'منشور جديد').of(context),
              onAction: _openComposer,
            );
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                96,
              ),
              itemCount: posts.length,
              itemBuilder: (_, index) {
                final post = posts[index];
                return Padding(
                  key: ValueKey(post.id),
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: CommunityPostCard(
                    post: post,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PostDetailPage(
                          user: widget.user,
                          post: post,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      backgroundColor: colors.background,
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
