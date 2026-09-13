import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../../../app/language_sync.dart';

import '../../legal/presentation/legal_page.dart';
import '../../messages/presentation/parent_requests_page.dart';
import '../../settings/presentation/notification_settings_page.dart';
import '../data/profile_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.user, required this.onSignOut});

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Mirrors widget.user.name, but updated immediately on a successful save
  // instead of waiting for this page's own rebuild from the auth stream —
  // that round-trip is what previously left an edited name showing stale
  // on this exact screen (every other screen reads a fresh live stream of
  // its own and updated fine) until the app restarted. Re-synced whenever
  // a genuinely new user object arrives (e.g. the background stream catches
  // up, or a different account signs in), so this never permanently
  // diverges from the real record.
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
    final colors = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: Text(const S('Profile', 'الملف الشخصي', fr: 'Profil', es: 'Perfil').of(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xl3,
        ),
        children: [
          _ProfileHeader(
            name: _displayName,
            email: user.email,
            onEdit: () => _editName(context),
          ),
          const SizedBox(height: AppSpacing.xl3),

          SectionHeader(
            title: const S('Your school', 'مدرستك', fr: 'Votre école', es: 'Su escuela').of(context),
          ),
          AppListCard(
            children: [
              SettingsTile(
                icon: Icons.forum_outlined,
                title: const S(
                  'Messages to school',
                  'رسايل للمدرسة',
                  fr: "Messages à l'école",
                  es: 'Mensajes a la escuela',
                ).of(context),
                subtitle: const S(
                  'Ask about a trip or a pickup change — the school passes '
                      'anything the driver needs on to them.',
                  'اسأل عن رحلة أو تغيير في الاستلام — المدرسة بتبلغ السواق '
                      'باللي يهمه.',
                  fr: "Posez une question sur un trajet ou un changement de "
                      "récupération — l'école transmet au chauffeur ce qu'il "
                      "doit savoir.",
                  es: 'Pregunte sobre un viaje o un cambio de recogida — la '
                      'escuela le comunica al conductor lo que necesite saber.',
                ).of(context),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textMuted,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ParentRequestsPage(user: user),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl3),

          SectionHeader(
            title: const S(
              'App settings',
              'إعدادات التطبيق',
              fr: "Paramètres de l'application",
              es: 'Ajustes de la aplicación',
            ).of(context),
          ),
          AppListCard(
            children: [
              ValueListenableBuilder<Locale>(
                valueListenable: AppSettings.locale,
                builder: (context, locale, _) => SettingsTile(
                  icon: Icons.translate_rounded,
                  tone: colors.info,
                  title: const S(
                    'Language',
                    'اللغة',
                    fr: 'Langue',
                    es: 'Idioma',
                  ).of(context),
                  // Shows the language currently in use. This used to name
                  // the language a tap would switch *to* — meaningful when
                  // there were exactly two, meaningless now that a tap
                  // opens a list of four.
                  subtitle: AppLanguage.fromCode(locale.languageCode).nativeName,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      showLanguagePickerSheet(context, onChanged: LanguageSync.save),
                ),
              ),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: AppSettings.themeMode,
                builder: (context, mode, _) {
                  final isDark = mode == ThemeMode.dark;
                  return SettingsTile(
                    icon: isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    tone: colors.warning,
                    title: const S(
                      'Dark mode',
                      'الوضع الليلي',
                      fr: 'Mode sombre',
                      es: 'Modo oscuro',
                    ).of(context),
                    subtitle: isDark
                        ? const S('On', 'مفعّل', fr: 'Activé', es: 'Activado').of(context)
                        : const S('Off', 'متوقف', fr: 'Désactivé', es: 'Desactivado').of(context),
                    trailing: Switch(
                      value: isDark,
                      onChanged: (_) => AppSettings.toggleTheme(),
                    ),
                    onTap: AppSettings.toggleTheme,
                  );
                },
              ),
              SettingsTile(
                icon: Icons.notifications_outlined,
                tone: colors.success,
                title: const S(
                  'Notification settings',
                  'إعدادات الإشعارات',
                  fr: 'Paramètres de notifications',
                  es: 'Ajustes de notificaciones',
                ).of(context),
                subtitle: const S(
                  'Choose which trip alerts reach your phone.',
                  'اختار تنبيهات الرحلة اللي توصل موبايلك.',
                  fr: 'Choisissez les alertes de trajet reçues sur votre téléphone.',
                  es: 'Elija las alertas de viaje que llegan a su teléfono.',
                ).of(context),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textMuted,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsPage(),
                  ),
                ),
              ),
              SettingsTile(
                icon: Icons.privacy_tip_outlined,
                tone: colors.textSecondary,
                title: const S(
                  'Privacy & Terms',
                  'الخصوصية والشروط',
                  fr: 'Confidentialité et conditions',
                  es: 'Privacidad y términos',
                ).of(context),
                subtitle: const S(
                  'What this app stores, and who can see it.',
                  'التطبيق بيخزن إيه، ومين يقدر يشوفه.',
                  fr: "Ce que l'application enregistre, et qui peut le voir.",
                  es: 'Qué guarda esta aplicación y quién puede verlo.',
                ).of(context),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textMuted,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LegalPage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl3),

          SectionHeader(title: const S('Account', 'الحساب', fr: 'Compte', es: 'Cuenta').of(context)),
          AppButton.secondary(
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
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(const S('Edit name', 'تعديل الاسم', fr: 'Modifier le nom', es: 'Editar nombre').of(dialogContext)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: const S('Your name', 'اسمك', fr: 'Votre nom', es: 'Su nombre').of(dialogContext),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(const S('Cancel', 'إلغاء', fr: 'Annuler', es: 'Cancelar').of(dialogContext)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(const S('Save', 'حفظ', fr: 'Enregistrer', es: 'Guardar').of(dialogContext)),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    // The write can fail (offline, a rules rejection, a transient Firestore
    // error) — previously nothing told the parent when that happened, so
    // an edited name would silently revert on the next reload with no
    // explanation. Surface it the same way every other in-app save failure
    // is surfaced.
    try {
      await ProfileRepository().updateName(schoolId: user.schoolId, name: trimmed);
      // Update this screen's own display immediately rather than waiting
      // for widget.user to catch up via the auth stream + a rebuild from
      // above — see _displayName's doc comment.
      if (mounted) setState(() => _displayName = trimmed);
    } catch (_) {
      if (!context.mounted) return;
      AppSnackbar.error(
        context,
        const S(
          "Couldn't save your name — try again.",
          'معرفناش نحفظ اسمك — جرب تاني.',
          fr: "Impossible d'enregistrer votre nom — réessayez.",
          es: 'No se pudo guardar su nombre — inténtelo de nuevo.',
        ).of(context),
      );
    }
  }
}

/// The identity card at the top of the hub: monogram, name, email, and the
/// one role this app ever has.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.onEdit,
  });

  final String name;
  final String email;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.tertiary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Text(
              name.trim().isEmpty
                  ? '?'
                  : name.trim().characters.first.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: const S('Edit name', 'تعديل الاسم', fr: 'Modifier le nom', es: 'Editar nombre').of(context),
                onPressed: onEdit,
              ),
            ],
          ),
          if (email.isNotEmpty)
            Text(
              email,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              const S('Parent', 'ولي أمر', fr: 'Parent', es: 'Padre/Madre').of(context),
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
