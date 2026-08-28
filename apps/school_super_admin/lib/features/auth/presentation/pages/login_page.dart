import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_shared/school_shared.dart';

import '../../../super_admin/presentation/super_admin_home_page.dart';
import '../../data/firebase_auth_repository.dart';
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
                              const S('Super Admin', 'المشرف العام').of(
                                context,
                              ),
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
                                labelText: const S('Email', 'الإيميل').of(
                                  context,
                                ),
                                prefixIcon: const Icon(
                                  Icons.alternate_email_rounded,
                                ),
                              ),
                              validator: (v) => (v ?? '').contains('@')
                                  ? null
                                  : const S(
                                      'Enter a valid email',
                                      'اكتب إيميل صحيح',
                                    ).of(context),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TextFormField(
                              controller: _password,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: const S('Password', 'كلمة السر').of(
                                  context,
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                              ),
                              validator: (v) => (v ?? '').isEmpty
                                  ? const S(
                                      'Enter your password',
                                      'اكتب كلمة السر',
                                    ).of(context)
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.xl2),
                            AppButton.primary(
                              label: const S('Sign in', 'تسجيل الدخول').of(
                                context,
                              ),
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
                                  ).of(context),
                                ),
                              ),
                            ),
                            if (state is AuthSignedOut &&
                                state.message != null)
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
                                        state.message!,
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
        const S('Reset password', 'استعادة كلمة السر').of(dialogContext),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            const S(
              "We'll email you a link to reset your password.",
              'هنبعتلك لينك على إيميلك عشان تغيّر كلمة السر.',
            ).of(dialogContext),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: const S('Email', 'الإيميل').of(dialogContext),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(const S('Cancel', 'إلغاء').of(dialogContext)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: Text(const S('Send', 'إرسال').of(dialogContext)),
        ),
      ],
    ),
  );
  controller.dispose();
  if (email == null || !email.contains('@') || !context.mounted) return;

  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  try {
    await FirebaseAuthRepository().sendPasswordResetEmail(email);
    if (!context.mounted) return;
    AppSnackbar.success(
      context,
      isArabic
          ? 'لو $email ليه حساب، بعتنالك لينك استعادة كلمة السر.'
          : "If $email has an account, we've sent a reset link.",
    );
  } catch (_) {
    if (!context.mounted) return;
    AppSnackbar.error(
      context,
      isArabic
          ? 'معرفناش نبعت إيميل الاستعادة — جرب تاني.'
          : "Couldn't send the reset email — try again.",
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
          tooltip: 'العربية / English',
          onPressed: AppSettings.toggleLocale,
          icon: const Icon(Icons.translate),
        ),
        const SizedBox(width: AppSpacing.sm),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: AppSettings.themeMode,
          builder: (context, mode, _) => IconButton.filledTonal(
            tooltip: 'Theme',
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
