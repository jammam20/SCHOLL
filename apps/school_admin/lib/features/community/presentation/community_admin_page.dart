import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../data/community_admin_repository.dart';
import 'community_category_ui.dart';
import 'community_post_admin_detail_page.dart';

enum _AdminCommunityFilter {
  all,
  complaint,
  busIssue,
  pickupPoint,
  delay,
  suggestion,
  question,
  reported,
}

/// The school's full community feed as the admin sees it (Feature: Parent
/// Community) — every status, real author identity resolved per post (see
/// [CommunityAdminRepository.resolveAuthor]), and the moderation actions
/// the parent app's own feed never exposes.
class CommunityAdminPage extends StatefulWidget {
  const CommunityAdminPage({super.key, required this.schoolId});

  final String schoolId;

  @override
  State<CommunityAdminPage> createState() => _CommunityAdminPageState();
}

class _CommunityAdminPageState extends State<CommunityAdminPage> {
  final _repository = CommunityAdminRepository();
  _AdminCommunityFilter _filter = _AdminCommunityFilter.all;
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  CommunityPostCategory? get _categoryFilter => switch (_filter) {
    _AdminCommunityFilter.complaint => CommunityPostCategory.complaint,
    _AdminCommunityFilter.busIssue => CommunityPostCategory.busIssue,
    _AdminCommunityFilter.pickupPoint => CommunityPostCategory.pickupPoint,
    _AdminCommunityFilter.delay => CommunityPostCategory.delay,
    _AdminCommunityFilter.suggestion => CommunityPostCategory.suggestion,
    _AdminCommunityFilter.question => CommunityPostCategory.question,
    _AdminCommunityFilter.all || _AdminCommunityFilter.reported => null,
  };

  String _filterLabel(BuildContext context, _AdminCommunityFilter filter) {
    return switch (filter) {
      _AdminCommunityFilter.all => const S(
        'All',
        'الكل',
        fr: 'Tous',
        es: 'Todos',
      ).of(context),
      _AdminCommunityFilter.complaint => const S(
        'Complaints',
        'الشكاوى',
        fr: 'Plaintes',
        es: 'Quejas',
      ).of(context),
      _AdminCommunityFilter.busIssue => const S(
        'Bus issues',
        'مشاكل الأتوبيس',
        fr: 'Problèmes de bus',
        es: 'Problemas con el autobús',
      ).of(context),
      _AdminCommunityFilter.pickupPoint => const S(
        'Pickup point',
        'نقطة الاستلام',
        fr: 'Point de ramassage',
        es: 'Punto de recogida',
      ).of(context),
      _AdminCommunityFilter.delay => const S(
        'Delay',
        'تأخير',
        fr: 'Retard',
        es: 'Retraso',
      ).of(context),
      _AdminCommunityFilter.suggestion => const S(
        'Suggestions',
        'اقتراحات',
        fr: 'Suggestions',
        es: 'Sugerencias',
      ).of(context),
      _AdminCommunityFilter.question => const S(
        'Questions',
        'أسئلة',
        fr: 'Questions',
        es: 'Preguntas',
      ).of(context),
      _AdminCommunityFilter.reported => const S(
        'Reports',
        'البلاغات',
        fr: 'Signalements',
        es: 'Reportes',
      ).of(context),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          const S(
            'Parent Community',
            'مجتمع أولياء الأمور',
            fr: 'Communauté des parents',
            es: 'Comunidad de familias',
          ).of(context),
        ),
        actions: [
          IconButton(
            tooltip: const S(
              'Search',
              'بحث',
              fr: 'Rechercher',
              es: 'Buscar',
            ).of(context),
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
                        fr: 'Rechercher des publications…',
                        es: 'Buscar publicaciones…',
                      ).of(context),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    children: [
                      for (final filter in _AdminCommunityFilter.values)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: Center(
                            child: ChoiceChip(
                              label: Text(_filterLabel(context, filter)),
                              selected: _filter == filter,
                              onSelected: (_) => setState(() => _filter = filter),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<List<CommunityPost>>(
        stream: _repository.watchAllPosts(
          schoolId: widget.schoolId,
          categoryFilter: _categoryFilter,
          onlyReported: _filter == _AdminCommunityFilter.reported,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: 4,
              itemBuilder: (_, index) => Padding(
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
                fr: 'Impossible de charger le fil de la communauté — '
                    'vérifiez votre connexion et réessayez.',
                es: 'No se pudo cargar el feed de la comunidad — comprueba '
                    'tu conexión e inténtalo de nuevo.',
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
                'No posts match this filter',
                'مفيش منشورات مطابقة للفلتر ده',
                fr: 'Aucune publication ne correspond à ce filtre',
                es: 'Ninguna publicación coincide con este filtro',
              ).of(context),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            itemCount: posts.length,
            itemBuilder: (_, index) {
              final post = posts[index];
              return Padding(
                key: ValueKey(post.id),
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _AdminPostCard(schoolId: widget.schoolId, post: post),
              );
            },
          );
        },
      ),
      backgroundColor: colors.background,
    );
  }
}

class _AdminPostCard extends StatelessWidget {
  const _AdminPostCard({required this.schoolId, required this.post});

  final String schoolId;
  final CommunityPost post;

  StatusTone get _tone => switch (post.status) {
    CommunityPostStatus.active => StatusTone.success,
    CommunityPostStatus.hidden => StatusTone.warning,
    CommunityPostStatus.archived => StatusTone.neutral,
    CommunityPostStatus.deleted => StatusTone.error,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final category = CommunityCategoryUi.of(post.category);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CommunityPostAdminDetailPage(schoolId: schoolId, post: post),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${category.emoji} ${category.label(context)}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.textSecondary,
                        ),
                      ),
                      StatusBadge(
                        label: communityStatusLabel(context, post.status),
                        tone: _tone,
                      ),
                      if (post.reportCount > 0)
                        StatusBadge(
                          label: S(
                            '${post.reportCount} report(s)',
                            '${post.reportCount} بلاغ',
                            fr: '${post.reportCount} signalement(s)',
                            es: '${post.reportCount} reporte(s)',
                          ).of(context),
                          tone: StatusTone.error,
                        ),
                    ],
                  ),
                ),
                Text(
                  communityRelativeTime(context, post.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              post.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.thumb_up_alt_outlined, size: 16, color: colors.textMuted),
                const SizedBox(width: 4),
                Text('${post.reactionCount}', style: theme.textTheme.bodySmall),
                const SizedBox(width: AppSpacing.md),
                Icon(Icons.mode_comment_outlined, size: 16, color: colors.textMuted),
                const SizedBox(width: 4),
                Text('${post.commentCount}', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
