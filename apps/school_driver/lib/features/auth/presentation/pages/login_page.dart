import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_shared/school_shared.dart';

import '../../../home/presentation/driver_home_page.dart';
import '../../data/firebase_auth_repository.dart';
import '../cubit/auth_cubit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _schoolCode = TextEditingController();
  bool _registering = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _schoolCode.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthCubit>();
    _registering
        ? auth.register(
            _name.text,
            _email.text,
            _password.text,
            _schoolCode.text,
          )
        : auth.signIn(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthCubit, AuthState>(
    builder: (context, state) {
      // DriverHomePage brings its own full-screen Scaffold (app bar + trip
      // list), so it must not be nested inside the sign-in form's centered,
      // width-constrained box below — it needs the whole screen.
      if (state is AuthSignedIn) {
        return DriverHomePage(
          user: state.user,
          onSignOut: context.read<AuthCubit>().signOut,
        );
      }

      final colors = Theme.of(context).colorScheme;

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
                      colors.primary.withValues(alpha: 0.10),
                      Theme.of(context).scaffoldBackgroundColor,
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
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl3),
                        child: switch (state) {
                          AuthPendingApproval() => _StatusCard(
                            icon: Icons.hourglass_top,
                            tone: StatusTone.warning,
                            badgeLabel: const S(
                              'Pending approval',
                              'قيد الموافقة',
                            ).of(context),
                            title: const S(
                              'Waiting for approval',
                              'في انتظار الموافقة',
                            ).of(context),
                            message: const S(
                              'Your driver account is registered but still '
                                  'needs to be approved by your school '
                                  'administrator. Check back soon.',
                              'حسابك مسجل بس لسه محتاج موافقة من أدمن '
                                  'مدرستك. ارجع تشيك تاني كمان شوية.',
                            ).of(context),
                            onSignOut: context.read<AuthCubit>().signOut,
                          ),
                          AuthRejected() => _StatusCard(
                            icon: Icons.block,
                            tone: StatusTone.error,
                            badgeLabel: const S(
                              'Rejected',
                              'مرفوض',
                            ).of(context),
                            title: const S(
                              'Registration rejected',
                              'تم رفض التسجيل',
                            ).of(context),
                            message: const S(
                              'Your school administrator did not approve '
                                  'this account. Contact your school for '
                                  'help.',
                              'أدمن مدرستك متمش موافقته على الحساب ده. '
                                  'كلّم مدرستك.',
                            ).of(context),
                            onSignOut: context.read<AuthCubit>().signOut,
                          ),
                          AuthDisabled() => _StatusCard(
                            icon: Icons.pause_circle_outline,
                            tone: StatusTone.neutral,
                            badgeLabel: const S(
                              'Disabled',
                              'متوقف',
                            ).of(context),
                            title: const S(
                              'Account disabled',
                              'الحساب متوقف',
                            ).of(context),
                            message: const S(
                              'Your account has been disabled. Contact your '
                                  'school administrator for help.',
                              'حسابك متوقف. كلّم أدمن مدرستك.',
                            ).of(context),
                            onSignOut: context.read<AuthCubit>().signOut,
                          ),
                          _ => _SignInForm(
                            formKey: _form,
                            name: _name,
                            email: _email,
                            password: _password,
                            schoolCode: _schoolCode,
                            registering: _registering,
                            state: state,
                            onSubmit: _submit,
                            onToggleRegistering: () =>
                                setState(() => _registering = !_registering),
                          ),
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const PositionedDirectional(
              top: AppSpacing.md,
              end: AppSpacing.md,
              child: _TopControls(),
            ),
          ],
        ),
      );
    },
  );
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

class _SignInForm extends StatelessWidget {
  const _SignInForm({
    required this.formKey,
    required this.name,
    required this.email,
    required this.password,
    required this.schoolCode,
    required this.registering,
    required this.state,
    required this.onSubmit,
    required this.onToggleRegistering,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController schoolCode;
  final bool registering;
  final AuthState state;
  final VoidCallback onSubmit;
  final VoidCallback onToggleRegistering;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final loading = state is AuthLoading;

    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.tertiary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(
              Icons.local_shipping,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            const S('Jammam Driver', 'تطبيق السواق').of(context),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            registering
                ? const S(
                    'Create your driver account',
                    'اعمل حسابك كسواق',
                  ).of(context)
                : const S('Welcome back', 'أهلاً بيك تاني').of(context),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl2 + AppSpacing.xs),
          if (registering)
            TextFormField(
              controller: name,
              decoration: InputDecoration(
                labelText: const S('Full name', 'الاسم بالكامل').of(context),
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? const S('Enter your name', 'اكتب اسمك').of(context)
                  : null,
            ),
          if (registering) const SizedBox(height: AppSpacing.lg),
          if (registering)
            TextFormField(
              controller: schoolCode,
              decoration: InputDecoration(
                labelText: const S('School code', 'كود المدرسة').of(context),
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? const S(
                      'Enter your school code',
                      'اكتب كود مدرستك',
                    ).of(context)
                  : null,
            ),
          if (registering) const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: const S('Email', 'الإيميل').of(context),
              prefixIcon: const Icon(Icons.mail_outline),
            ),
            validator: (v) => (v ?? '').contains('@')
                ? null
                : const S('Enter a valid email', 'اكتب إيميل صحيح').of(context),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: password,
            obscureText: true,
            decoration: InputDecoration(
              labelText: const S('Password', 'كلمة السر').of(context),
              prefixIcon: const Icon(Icons.lock_outline),
            ),
            validator: (v) => registering
                ? ((v ?? '').length >= 8
                      ? null
                      : const S(
                          'Use at least 8 characters',
                          'لازم 8 حروف على الأقل',
                        ).of(context))
                : ((v ?? '').isEmpty
                      ? const S('Enter your password', 'اكتب كلمة السر').of(
                          context,
                        )
                      : null),
          ),
          const SizedBox(height: AppSpacing.xl2),
          AppButton.primary(
            label: registering
                ? const S('Create account', 'إنشاء الحساب').of(context)
                : const S('Sign in', 'تسجيل الدخول').of(context),
            loading: loading,
            onPressed: onSubmit,
          ),
          if (!registering)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: loading
                    ? null
                    : () => _showForgotPasswordDialog(context, email.text),
                child: Text(
                  const S('Forgot password?', 'نسيت كلمة السر؟').of(context),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: loading ? null : onToggleRegistering,
            child: Text(
              registering
                  ? const S(
                      'I already have an account',
                      'عندي حساب بالفعل',
                    ).of(context)
                  : const S(
                      'Create a driver account',
                      'اعمل حساب سواق',
                    ).of(context),
            ),
          ),
          if (state is AuthSignedOut && (state as AuthSignedOut).message != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline_rounded, size: 16, color: colors.error),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      (state as AuthSignedOut).message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.tone,
    required this.badgeLabel,
    required this.title,
    required this.message,
    required this.onSignOut,
  });

  final IconData icon;
  final StatusTone tone;
  final String badgeLabel;
  final String title;
  final String message;
  final VoidCallback onSignOut;

  Color _toneColor(AppColorTokens colors) => switch (tone) {
    StatusTone.success => colors.success,
    StatusTone.warning => colors.warning,
    StatusTone.error => colors.error,
    StatusTone.info => colors.info,
    StatusTone.emergency => colors.emergency,
    StatusTone.neutral => colors.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final toneColor = _toneColor(colors);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: toneColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 34, color: toneColor),
        ),
        const SizedBox(height: AppSpacing.lg),
        StatusBadge(label: badgeLabel, tone: tone),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl2),
        AppButton.secondary(
          label: const S('Sign out', 'تسجيل الخروج').of(context),
          onPressed: onSignOut,
        ),
      ],
    );
  }
}

Future<void> _showForgotPasswordDialog(
  BuildContext context,
  String initialEmail,
) async {
  final controller = TextEditingController(text: initialEmail);
  final email = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(const S('Reset password', 'استعادة كلمة السر').of(dialogContext)),
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
              prefixIcon: const Icon(Icons.mail_outline),
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
