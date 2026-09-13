import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../data/community_repository.dart';
import 'community_category_ui.dart';

/// Max length enforced client-side — a generous ceiling for a genuine
/// question/complaint without inviting an essay. firestore.rules backstops
/// this server-side at a larger byte ceiling (4000) purely against a
/// malicious client bypassing this screen entirely, not as the real UX
/// limit.
const _maxContentLength = 1000;

/// The "+ New post" composer (Feature: Parent Community). A category is
/// required (defaults to the first one) and content must be non-empty and
/// under [_maxContentLength] — both enforced here before the repository is
/// ever called, so the only way [CommunityRepository.createPost] fails is a
/// genuine network/permission problem, which the error state below handles.
class PostComposerPage extends StatefulWidget {
  const PostComposerPage({
    super.key,
    required this.schoolId,
    required this.parentUid,
  });

  final String schoolId;
  final String parentUid;

  @override
  State<PostComposerPage> createState() => _PostComposerPageState();
}

class _PostComposerPageState extends State<PostComposerPage> {
  final _repository = CommunityRepository();
  final _controller = TextEditingController();
  CommunityPostCategory _category = CommunityPostCategory.question;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _contentValid {
    final trimmed = _controller.text.trim();
    return trimmed.isNotEmpty && trimmed.length <= _maxContentLength;
  }

  Future<void> _submit() async {
    if (!_contentValid || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _repository.createPost(
        schoolId: widget.schoolId,
        parentUid: widget.parentUid,
        category: _category,
        content: _controller.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = const S(
          "Couldn't post — check your connection and try again.",
          'معرفناش ننشر — اتأكد من الاتصال وجرب تاني.',
          fr: "Impossible de publier — vérifiez votre connexion et réessayez.",
          es: 'No se pudo publicar — revise su conexión e inténtelo de nuevo.',
        ).of(context);
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final length = _controller.text.trim().length;
    final overLimit = length > _maxContentLength;

    return Scaffold(
      appBar: AppBar(
        title: Text(const S('New post', 'منشور جديد', fr: 'Nouvelle publication', es: 'Nueva publicación').of(context)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: AppButton.primary(
                label: const S('Post', 'نشر', fr: 'Publier', es: 'Publicar').of(context),
                loading: _submitting,
                onPressed: _contentValid ? _submit : null,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            const S(
              'Your identity is anonymous to other parents',
              'هويتك مجهولة بالنسبة لباقي أولياء الأمور',
              fr: 'Votre identité est anonyme pour les autres parents',
              es: 'Su identidad es anónima para los demás padres',
            ).of(context),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            const S('Category', 'التصنيف', fr: 'Catégorie', es: 'Categoría').of(context).toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in CommunityPostCategory.values)
                ChoiceChip(
                  label: Text(
                    '${CommunityCategoryUi.of(category).emoji} '
                    '${CommunityCategoryUi.of(category).label(context)}',
                  ),
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            const S(
              'What happened?',
              'حصل إيه؟',
              fr: "Que s'est-il passé ?",
              es: '¿Qué pasó?',
            ).of(context).toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            maxLines: 6,
            minLines: 4,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: const S(
                'Share a problem, a question, a suggestion…',
                'شارك مشكلة أو سؤال أو اقتراح…',
                fr: 'Partagez un problème, une question, une suggestion…',
                es: 'Comparta un problema, una pregunta, una sugerencia…',
              ).of(context),
              errorText: overLimit
                  ? const S(
                      'Too long — please shorten it.',
                      'طويل أوي — اختصره من فضلك.',
                      fr: 'Trop long — veuillez le raccourcir.',
                      es: 'Demasiado largo — por favor acórtelo.',
                    ).of(context)
                  : null,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              '$length/$_maxContentLength',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: overLimit ? colors.error : colors.textMuted,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.error_outline_rounded, color: colors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!, style: TextStyle(color: colors.error)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
