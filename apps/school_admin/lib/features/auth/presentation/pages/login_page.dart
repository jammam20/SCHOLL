import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_shared/school_shared.dart';

import '../../../admin/presentation/admin_home_page.dart';
import '../../../staff/presentation/staff_home_page.dart';
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
      // AdminHomePage/StaffHomePage each bring their own full-screen
      // Scaffold (tab bar), so neither must be nested inside the sign-in
      // form's centered, width-constrained box below.
      //
      // This is the app's single post-login role branch: `staff` is a
      // read-only operational role and gets a shell with no write actions
      // anywhere, never the admin one with its controls hidden.
      if (state is AuthSignedIn) {
        final signOut = context.read<AuthCubit>().signOut;
        return state.user.role == UserRole.staff
            ? StaffHomePage(user: state.user, onSignOut: signOut)
            : AdminHomePage(user: state.user, onSignOut: signOut);
      }

      final colors = Theme.of(context).colorScheme;
      final appColors = context.appColors;

      return Scaffold(
        backgroundColor: appColors.background,
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
                      appColors.background,
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
                            statusLabel: const S(
                              'Pending approval',
                              'في انتظار الموافقة',
                            ).of(context),
                            title: S(
                              'Waiting for approval',
                              'في انتظار الموافقة',
                            ).of(context),
                            message: const S(
                              'Your administrator account is registered but '
                                  'still needs to be approved. If this is a '
                                  "brand-new school, the platform's super "
                                  'admin will approve it; otherwise an '
                                  'existing admin at your school will.',
                              'حساب المدير مسجل بس لسه محتاج موافقة. لو '
                                  'دي مدرسة جديدة، الـ Super Admin هو اللي '
                                  'هيوافق؛ غير كده أي أدمن موجود في '
                                  'مدرستك.',
                            ).of(context),
                            onSignOut: context.read<AuthCubit>().signOut,
                          ),
                          AuthRejected(:final user) => _StatusCard(
                            icon: Icons.block,
                            tone: StatusTone.error,
                            statusLabel: const S(
                              'Rejected',
                              'مرفوض',
                            ).of(context),
                            title: S(
                              'Registration rejected',
                              'تم رفض التسجيل',
                            ).of(context),
                            message:
                                user.rejectionReason?.isNotEmpty == true
                                ? S(
                                    'This administrator account was not '
                                        'approved: ${user.rejectionReason}',
                                    'حساب المدير ده متمش الموافقة عليه: '
                                        '${user.rejectionReason}',
                                  ).of(context)
                                : const S(
                                    'This administrator account was not '
                                        'approved.',
                                    'حساب المدير ده متمش الموافقة عليه.',
                                  ).of(context),
                            onSignOut: context.read<AuthCubit>().signOut,
                          ),
                          AuthDisabled() => _StatusCard(
                            icon: Icons.pause_circle_outline,
                            tone: StatusTone.neutral,
                            statusLabel: const S(
                              'Disabled',
                              'متوقف',
                            ).of(context),
                            title: S(
                              'Account disabled',
                              'الحساب متوقف',
                            ).of(context),
                            message: const S(
                              'Your account has been disabled.',
                              'تم إيقاف حسابك.',
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
            PositionedDirectional(
              top: AppSpacing.md,
              end: AppSpacing.md,
              child: const _TopControls(),
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
          tooltip: const S('Language', 'اللغة', fr: 'Langue', es: 'Idioma').of(context),
          onPressed: () => showLanguagePickerSheet(context),
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
    final colors = theme.colorScheme;
    final appColors = context.appColors;

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
                colors: [colors.primary, colors.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.directions_bus_filled,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            const S(
              'Jammam School Operations',
              'إدارة المدرسة',
            ).of(context),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            registering
                ? const S(
                    "Register your school's account",
                    'سجّل حساب مدرستك',
                  ).of(context)
                : const S('Welcome back', 'أهلاً بيك تاني').of(context),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl2 + AppSpacing.xs),
          if (registering)
            TextFormField(
              controller: name,
              decoration: InputDecoration(
                labelText: const S('Full name', 'الاسم بالكامل').of(context),
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? const S(
                      'Enter your name',
                      'اكتب اسمك',
                    ).of(context)
                  : null,
            ),
          if (registering) const SizedBox(height: AppSpacing.lg),
          if (registering)
            TextFormField(
              controller: schoolCode,
              decoration: InputDecoration(
                labelText: const S('School code', 'كود المدرسة').of(context),
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
            decoration: InputDecoration(
              labelText: const S('Email', 'الإيميل').of(context),
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
            controller: password,
            obscureText: true,
            decoration: InputDecoration(
              labelText: const S('Password', 'كلمة السر').of(context),
            ),
            validator: (v) => registering
                ? ((v ?? '').length >= 8
                      ? null
                      : const S(
                          'Use at least 8 characters',
                          'لازم 8 حروف على الأقل',
                        ).of(context))
                : ((v ?? '').isEmpty
                      ? const S(
                          'Enter your password',
                          'اكتب كلمة السر',
                        ).of(context)
                      : null),
          ),
          const SizedBox(height: AppSpacing.xl2),
          AppButton.primary(
            label: registering
                ? const S('Create account', 'إنشاء الحساب').of(context)
                : const S('Sign in', 'تسجيل الدخول').of(context),
            onPressed: onSubmit,
            loading: state is AuthLoading,
          ),
          if (!registering)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: state is AuthLoading
                    ? null
                    : () => _showForgotPasswordDialog(context, email.text),
                child: Text(
                  const S('Forgot password?', 'نسيت كلمة السر؟').of(context),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: state is AuthLoading ? null : onToggleRegistering,
            child: Text(
              registering
                  ? const S(
                      'I already have an account',
                      'عندي حساب بالفعل',
                    ).of(context)
                  : const S(
                      "Register my school's account",
                      'سجّل حساب مدرستي',
                    ).of(context),
            ),
          ),
          if (state is AuthSignedOut && (state as AuthSignedOut).message != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: appColors.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: appColors.error,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        (state as AuthSignedOut).message!,
                        style: TextStyle(color: appColors.error),
                      ),
                    ),
                  ],
                ),
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
    required this.statusLabel,
    required this.title,
    required this.message,
    required this.onSignOut,
  });

  final IconData icon;
  final StatusTone tone;
  final String statusLabel;
  final String title;
  final String message;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = context.appColors;
    final accent = switch (tone) {
      StatusTone.success => appColors.success,
      StatusTone.warning => appColors.warning,
      StatusTone.error => appColors.error,
      StatusTone.info => appColors.info,
      StatusTone.emergency => appColors.emergency,
      StatusTone.neutral => appColors.textMuted,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 32, color: accent),
        ),
        const SizedBox(height: AppSpacing.lg),
        StatusBadge(label: statusLabel, tone: tone),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
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
          const SizedBox(height: 16),
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
  // Deliberately not disposed here: the dialog's own TextField is still
  // mounted and mid-exit-transition when this Future resolves (showDialog
  // completes as soon as Navigator.pop is called, before the reverse
  // animation finishes), so an immediate dispose() crashes with "A
  // TextEditingController was used after being disposed" the next time
  // that still-animating TextField rebuilds. A short-lived, unowned
  // controller with no other resources is safe to just let the GC
  // collect once this closure returns.
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
