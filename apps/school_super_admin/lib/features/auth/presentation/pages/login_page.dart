import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_shared/school_shared.dart';

import '../../../super_admin/presentation/super_admin_home_page.dart';
import '../../data/firebase_auth_repository.dart';
import '../auth_failure_message.dart';
import '../cubit/auth_cubit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    context.read<AuthCubit>().signIn(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthCubit, AuthState>(
    builder: (context, state) {
      if (state is AuthSignedIn) {
        return SuperAdminHomePage(
          name: state.profile.name,
          onSignOut: context.read<AuthCubit>().signOut,
        );
      }

      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      final appColors = context.appColors;
      final isLoading = state is AuthLoading;

      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary.withValues(alpha: 0.14),
                      theme.scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl2),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.xl3),
                      decoration: BoxDecoration(
                        color: appColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: appColors.border),
                        boxShadow: AppShadows.level2(appColors.textPrimary),
                      ),
                      child: Form(
                        key: _form,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [colors.primary, colors.tertiary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              child: Icon(
                                Icons.admin_panel_settings,
                                color: colors.onPrimary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              const S(
                                'Super Admin',
                                'المشرف العام',
                                fr: 'Super administrateur',
                                es: 'Superadministrador',
                              ).of(context),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: appColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              const S(
                                'Platform control panel — manage every '
                                    'school from one place',
                                'لوحة تحكم المنصة — تحكم في كل المدارس '
                                    'من مكان واحد',
                                fr:
                                    'Panneau de contrôle de la plateforme — '
                                    'gérez toutes les écoles depuis un seul '
                                    'endroit',
                                es:
                                    'Panel de control de la plataforma — '
                                    'gestiona todas las escuelas desde un '
                                    'solo lugar',
                              ).of(context),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: appColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl3),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: const S(
                                  'Email',
                                  'الإيميل',
                                  fr: 'E-mail',
                                  es: 'Correo electrónico',
                                ).of(context),
                                prefixIcon: const Icon(
                                  Icons.alternate_email_rounded,
                                ),
                              ),
                              validator: (v) => (v ?? '').contains('@')
                                  ? null
                                  : const S(
                                      'Enter a valid email',
                                      'اكتب إيميل صحيح',
                                      fr: 'Saisissez une adresse e-mail valide',
                                      es: 'Introduce un correo electrónico válido',
                                    ).of(context),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TextFormField(
                              controller: _password,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: const S(
                                  'Password',
                                  'كلمة السر',
                                  fr: 'Mot de passe',
                                  es: 'Contraseña',
                                ).of(context),
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                              ),
                              validator: (v) => (v ?? '').isEmpty
                                  ? const S(
                                      'Enter your password',
                                      'اكتب كلمة السر',
                                      fr: 'Saisissez votre mot de passe',
                                      es: 'Introduce tu contraseña',
                                    ).of(context)
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.xl2),
                            AppButton.primary(
                              label: const S(
                                'Sign in',
                                'تسجيل الدخول',
                                fr: 'Se connecter',
                                es: 'Iniciar sesión',
                              ).of(context),
                              onPressed: isLoading ? null : _submit,
                              loading: isLoading,
                            ),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () => _showForgotPasswordDialog(
                                        context,
                                        _email.text,
                                      ),
                                child: Text(
                                  const S(
                                    'Forgot password?',
                                    'نسيت كلمة السر؟',
                                    fr: 'Mot de passe oublié ?',
                                    es: '¿Olvidaste tu contraseña?',
                                  ).of(context),
                                ),
                              ),
                            ),
                            if (state is AuthSignedOut &&
                                state.code != null)
                              Container(
                                margin: const EdgeInsets.only(
                                  top: AppSpacing.sm,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: appColors.error.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      size: 18,
                                      color: appColors.error,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        authFailureMessage(
                                          state.code!,
                                          context,
                                        ),
                                        style: TextStyle(
                                          color: appColors.error,
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
                  ),
                ),
              ),
            ),
            const PositionedDirectional(top: 12, end: 12, child: _TopControls()),
          ],
        ),
      );
    },
  );
}

Future<void> _showForgotPasswordDialog(
  BuildContext context,
  String initialEmail,
) async {
  final controller = TextEditingController(text: initialEmail);
  final email = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        const S(
          'Reset password',
          'استعادة كلمة السر',
          fr: 'Réinitialiser le mot de passe',
          es: 'Restablecer contraseña',
        ).of(dialogContext),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            const S(
              "We'll email you a link to reset your password.",
              'هنبعتلك لينك على إيميلك عشان تغيّر كلمة السر.',
              fr:
                  'Nous vous enverrons un lien par e-mail pour réinitialiser '
                  'votre mot de passe.',
              es:
                  'Te enviaremos un enlace por correo electrónico para '
                  'restablecer tu contraseña.',
            ).of(dialogContext),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: const S(
                'Email',
                'الإيميل',
                fr: 'E-mail',
                es: 'Correo electrónico',
              ).of(dialogContext),
            ),
          ),
        ],
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
            const S(
              'Send',
              'إرسال',
              fr: 'Envoyer',
              es: 'Enviar',
            ).of(dialogContext),
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
  if (email == null || !email.contains('@') || !context.mounted) return;

  try {
    await FirebaseAuthRepository().sendPasswordResetEmail(email);
    if (!context.mounted) return;
    AppSnackbar.success(
      context,
      S(
        "If $email has an account, we've sent a reset link.",
        'لو $email ليه حساب، بعتنالك لينك استعادة كلمة السر.',
        fr:
            'Si $email correspond à un compte, nous avons envoyé un lien '
            'de réinitialisation.',
        es:
            'Si $email tiene una cuenta, te hemos enviado un enlace para '
            'restablecer la contraseña.',
      ).of(context),
    );
  } catch (_) {
    if (!context.mounted) return;
    AppSnackbar.error(
      context,
      const S(
        "Couldn't send the reset email — try again.",
        'معرفناش نبعت إيميل الاستعادة — جرب تاني.',
        fr: "Impossible d'envoyer l'e-mail de réinitialisation — réessayez.",
        es:
            'No se pudo enviar el correo de restablecimiento — inténtalo '
            'de nuevo.',
      ).of(context),
    );
  }
}

class _TopControls extends StatelessWidget {
  const _TopControls();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: const S('Language', 'اللغة', fr: 'Langue', es: 'Idioma').of(context),
          onPressed: () => showLanguagePickerSheet(context),
          icon: const Icon(Icons.translate),
        ),
        const SizedBox(width: AppSpacing.sm),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: AppSettings.themeMode,
          builder: (context, mode, _) => IconButton.filledTonal(
            tooltip: const S(
              'Theme',
              'المظهر',
              fr: 'Thème',
              es: 'Tema',
            ).of(context),
            onPressed: AppSettings.toggleTheme,
            icon: Icon(
              mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
            ),
          ),
        ),
      ],
    );
  }
}
