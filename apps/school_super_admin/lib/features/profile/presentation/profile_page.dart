import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../../legal/presentation/legal_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.name, required this.onSignOut});

  final String name;
  final VoidCallback onSignOut;

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: const S('Sign out?', 'تسجيل الخروج؟').of(context),
      message: const S(
        "You'll need to sign in again to access the platform control "
            'panel.',
        'هتحتاج تسجل دخولك تاني عشان توصل للوحة تحكم المنصة.',
      ).of(context),
      confirmLabel: const S('Sign out', 'تسجيل الخروج').of(context),
      cancelLabel: const S('Cancel', 'إلغاء').of(context),
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
        title: Text(const S('Profile', 'الملف الشخصي').of(context)),
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
                    const S('Platform owner', 'مالك المنصة').of(context),
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
            title: const S('Preferences', 'التفضيلات').of(context),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: Text(const S('Language', 'اللغة').of(context)),
                  subtitle: ValueListenableBuilder<Locale>(
                    valueListenable: AppSettings.locale,
                    builder: (context, locale, _) => Text(
                      locale.languageCode == 'ar' ? 'العربية' : 'English',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: AppSettings.toggleLocale,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: Text(const S('Dark mode', 'الوضع الليلي').of(context)),
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
                    const S('Privacy & Terms', 'الخصوصية والشروط').of(context),
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
            label: const S('Sign out', 'تسجيل الخروج').of(context),
            icon: Icons.logout,
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      ),
    );
  }
}
