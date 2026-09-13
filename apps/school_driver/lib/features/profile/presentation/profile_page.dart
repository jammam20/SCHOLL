import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../../../app/language_sync.dart';

import '../../legal/presentation/legal_page.dart';
import '../data/profile_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.user, required this.onSignOut});

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // See parent app's ProfilePage for why this exists: an edit here
  // previously only showed up on every *other* screen, since those read a
  // fresh live stream of their own — this exact page had to wait for the
  // auth stream to round-trip back down through a rebuild from above,
  // which only actually happened after an app restart.
  late String _displayName = widget.user.name;

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user.name != oldWidget.user.name) {
      _displayName = widget.user.name;
    }
  }

  AppUser get user => widget.user;
  VoidCallback get onSignOut => widget.onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          const S(
            'Profile',
            'الملف الشخصي',
            fr: 'Profil',
            es: 'Perfil',
          ).of(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.primary, colors.tertiary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _displayName.isEmpty ? '?' : _displayName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _displayName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: const S(
                        'Edit name',
                        'تعديل الاسم',
                        fr: 'Modifier le nom',
                        es: 'Editar nombre',
                      ).of(context),
                      onPressed: () => _editName(context),
                    ),
                  ],
                ),
                if (user.email.isNotEmpty)
                  Text(user.email, style: TextStyle(color: colors.onSurfaceVariant)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    const S(
                      'Driver',
                      'سائق',
                      fr: 'Chauffeur',
                      es: 'Conductor',
                    ).of(context),
                    style: TextStyle(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl3),
          SectionHeader(
            title: const S(
              'Preferences',
              'التفضيلات',
              fr: 'Préférences',
              es: 'Preferencias',
            ).of(context),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: Text(const S('Language', 'اللغة', fr: 'Langue', es: 'Idioma').of(context)),
                  subtitle: ValueListenableBuilder<Locale>(
                    valueListenable: AppSettings.locale,
                    builder: (context, locale, _) =>
                        Text(AppLanguage.fromCode(locale.languageCode).nativeName),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      showLanguagePickerSheet(context, onChanged: LanguageSync.save),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: Text(
                    const S(
                      'Dark mode',
                      'الوضع الليلي',
                      fr: 'Mode sombre',
                      es: 'Modo oscuro',
                    ).of(context),
                  ),
                  trailing: ValueListenableBuilder<ThemeMode>(
                    valueListenable: AppSettings.themeMode,
                    builder: (context, mode, _) => Switch(
                      value: mode == ThemeMode.dark,
                      onChanged: (_) => AppSettings.toggleTheme(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(
                    const S(
                      'Privacy & Terms',
                      'الخصوصية والشروط',
                      fr: 'Confidentialité et conditions',
                      es: 'Privacidad y términos',
                    ).of(context),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LegalPage()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl3),
          AppButton.destructive(
            label: const S(
              'Sign out',
              'تسجيل الخروج',
              fr: 'Se déconnecter',
              es: 'Cerrar sesión',
            ).of(context),
            icon: Icons.logout,
            onPressed: onSignOut,
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(text: _displayName);
    var isSaving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(
            const S(
              'Edit name',
              'تعديل الاسم',
              fr: 'Modifier le nom',
              es: 'Editar nombre',
            ).of(dialogContext),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            enabled: !isSaving,
          ),
          actions: [
            TextButton(
              onPressed: isSaving
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: Text(
                const S(
                  'Cancel',
                  'إلغاء',
                  fr: 'Annuler',
                  es: 'Cancelar',
                ).of(dialogContext),
              ),
            ),
            AppButton.primary(
              label: const S(
                'Save',
                'حفظ',
                fr: 'Enregistrer',
                es: 'Guardar',
              ).of(dialogContext),
              loading: isSaving,
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                setState(() => isSaving = true);
                try {
                  await ProfileRepository().updateName(
                    schoolId: user.schoolId,
                    name: name,
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (_) {
                  if (dialogContext.mounted) {
                    setState(() => isSaving = false);
                    AppSnackbar.error(
                      dialogContext,
                      const S(
                        "Couldn't save your name — try again.",
                        'تعذّر حفظ اسمك — حاول مرة أخرى.',
                        fr: "Impossible d'enregistrer votre nom — "
                            'réessayez.',
                        es: 'No se pudo guardar tu nombre — inténtalo '
                            'de nuevo.',
                      ).of(dialogContext),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );

    final savedName = controller.text.trim();
    controller.dispose();
    if (saved == true && context.mounted) {
      setState(() => _displayName = savedName);
      AppSnackbar.success(
        context,
        const S(
          'Name updated',
          'تم تحديث الاسم',
          fr: 'Nom mis à jour',
          es: 'Nombre actualizado',
        ).of(context),
      );
    }
  }
}
