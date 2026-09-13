import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../../../app/language_sync.dart';

import '../../legal/presentation/legal_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.name, required this.onSignOut});

  final String name;
  final VoidCallback onSignOut;

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: const S(
        'Sign out?',
        'تسجيل الخروج؟',
        fr: 'Se déconnecter ?',
        es: '¿Cerrar sesión?',
      ).of(context),
      message: const S(
        "You'll need to sign in again to access the platform control "
            'panel.',
        'هتحتاج تسجل دخولك تاني عشان توصل للوحة تحكم المنصة.',
        fr:
            'Vous devrez vous reconnecter pour accéder au panneau de '
            'contrôle de la plateforme.',
        es:
            'Deberás iniciar sesión de nuevo para acceder al panel de '
            'control de la plataforma.',
      ).of(context),
      confirmLabel: const S(
        'Sign out',
        'تسجيل الخروج',
        fr: 'Se déconnecter',
        es: 'Cerrar sesión',
      ).of(context),
      cancelLabel: const S(
        'Cancel',
        'إلغاء',
        fr: 'Annuler',
        es: 'Cancelar',
      ).of(context),
      destructive: true,
    );
    if (confirmed == true) onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final appColors = context.appColors;

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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xl3,
        ),
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
                  child: Icon(
                    Icons.admin_panel_settings,
                    color: colors.onPrimary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: appColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    const S(
                      'Platform owner',
                      'مالك المنصة',
                      fr: 'Propriétaire de la plateforme',
                      es: 'Propietario de la plataforma',
                    ).of(context),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.onPrimaryContainer,
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
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      ),
    );
  }
}
