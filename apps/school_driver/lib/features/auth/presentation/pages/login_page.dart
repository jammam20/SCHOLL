import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/app_settings.dart';
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
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: switch (state) {
                          AuthPendingApproval() => _StatusCard(
                            icon: Icons.hourglass_top,
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
            const Positioned(top: 12, right: 12, child: _TopControls()),
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
        const SizedBox(width: 8),
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
    final colors = Theme.of(context).colorScheme;

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
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_shipping,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            const S('Jammam Driver', 'تطبيق السواق').of(context),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            registering
                ? const S(
                    'Create your driver account',
                    'اعمل حسابك كسواق',
                  ).of(context)
                : const S('Welcome back', 'أهلاً بيك تاني').of(context),
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          if (registering)
            TextFormField(
              controller: name,
              decoration: InputDecoration(
                labelText: const S('Full name', 'الاسم بالكامل').of(context),
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? const S('Enter your name', 'اكتب اسمك').of(context)
                  : null,
            ),
          if (registering) const SizedBox(height: 16),
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
          if (registering) const SizedBox(height: 16),
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: const S('Email', 'الإيميل').of(context),
            ),
            validator: (v) => (v ?? '').contains('@')
                ? null
                : const S('Enter a valid email', 'اكتب إيميل صحيح').of(context),
          ),
          const SizedBox(height: 16),
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
                      ? const S('Enter your password', 'اكتب كلمة السر').of(
                          context,
                        )
                      : null),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: state is AuthLoading ? null : onSubmit,
            child: Text(
              state is AuthLoading
                  ? const S('Please wait…', 'لحظة من فضلك…').of(context)
                  : (registering
                        ? const S('Create account', 'إنشاء الحساب').of(context)
                        : const S('Sign in', 'تسجيل الدخول').of(context)),
            ),
          ),
          if (!registering)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: state is AuthLoading
                    ? null
                    : () => _showForgotPasswordDialog(context, email.text),
                child: Text(
                  const S('Forgot password?', 'نسيت كلمة السر؟').of(context),
                ),
              ),
            ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: state is AuthLoading ? null : onToggleRegistering,
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
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                (state as AuthSignedOut).message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.error),
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
    required this.title,
    required this.message,
    required this.onSignOut,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 12),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      OutlinedButton(onPressed: onSignOut, child: const Text('Sign out')),
    ],
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
  controller.dispose();
  if (email == null || !email.contains('@') || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  try {
    await FirebaseAuthRepository().sendPasswordResetEmail(email);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          isArabic
              ? 'لو $email ليه حساب، بعتنالك لينك استعادة كلمة السر.'
              : "If $email has an account, we've sent a reset link.",
        ),
      ),
    );
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          isArabic
              ? 'معرفناش نبعت إيميل الاستعادة — جرب تاني.'
              : "Couldn't send the reset email — try again.",
        ),
      ),
    );
  }
}
