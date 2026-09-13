import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_shared/school_shared.dart';

import '../../../home/presentation/parent_home_page.dart';
import '../../data/firebase_auth_repository.dart';
import '../cubit/auth_cubit.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
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
    if (!(_formKey.currentState?.validate() ?? false)) return;
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
      // ParentHomePage brings its own full-screen Scaffold (app bar +
      // per-child trip/map cards), so it must not be nested inside the
      // sign-in form's centered, width-constrained box below.
      if (state is AuthSignedIn) {
        return ParentHomePage(
          user: state.user,
          onSignOut: context.read<AuthCubit>().signOut,
        );
      }

      final colors = context.appColors;

      return Scaffold(
        backgroundColor: colors.background,
        body: Stack(
          children: [
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
                            title: const S(
                              'Waiting for approval',
                              'في انتظار الموافقة',
                              fr: "En attente d'approbation",
                              es: 'Esperando aprobación',
                            ).of(context),
                            message: const S(
                              'Your account is registered but still needs to '
                                  'be approved by your school administrator. '
                                  'Check back soon.',
                              'حسابك مسجل بس لسه محتاج موافقة من أدمن '
                                  'مدرستك. ارجع تشيك تاني كمان شوية.',
                              fr:
                                  'Votre compte est enregistré mais doit '
                                  "encore être approuvé par l'administrateur "
                                  'de votre école. Revenez bientôt.',
                              es:
                                  'Tu cuenta está registrada, pero aún debe '
                                  'ser aprobada por el administrador de tu '
                                  'escuela. Vuelve a comprobarlo pronto.',
                            ).of(context),
                            onSignOut: context.read<AuthCubit>().signOut,
                          ),
                          AuthRejected(:final user) => _StatusCard(
                            icon: Icons.block,
                            tone: StatusTone.error,
                            title: const S(
                              'Registration rejected',
                              'تم رفض التسجيل',
                              fr: 'Inscription refusée',
                              es: 'Registro rechazado',
                            ).of(context),
                            message:
                                user.rejectionReason?.isNotEmpty == true
                                ? S(
                                    'Your school administrator did not '
                                        'approve this account: '
                                        '${user.rejectionReason}',
                                    'أدمن مدرستك متمش موافقته على الحساب '
                                        'ده: ${user.rejectionReason}',
                                    fr:
                                        "L'administrateur de votre école "
                                        "n'a pas approuvé ce compte : "
                                        '${user.rejectionReason}',
                                    es:
                                        'El administrador de tu escuela no '
                                        'aprobó esta cuenta: '
                                        '${user.rejectionReason}',
                                  ).of(context)
                                : const S(
                                    'Your school administrator did not '
                                        'approve this account. Contact '
                                        'your school for help.',
                                    'أدمن مدرستك متمش موافقته على الحساب '
                                        'ده. كلّم مدرستك.',
                                    fr:
                                        "L'administrateur de votre école "
                                        "n'a pas approuvé ce compte. "
                                        'Contactez votre école pour '
                                        "obtenir de l'aide.",
                                    es:
                                        'El administrador de tu escuela no '
                                        'aprobó esta cuenta. Contacta con '
                                        'tu escuela para obtener ayuda.',
                                  ).of(context),
                            onSignOut: context.read<AuthCubit>().signOut,
                          ),
                          AuthDisabled() => _StatusCard(
                            icon: Icons.pause_circle_outline,
                            tone: StatusTone.neutral,
                            title: const S(
                              'Account disabled',
                              'الحساب متوقف',
                              fr: 'Compte désactivé',
                              es: 'Cuenta deshabilitada',
                            ).of(context),
                            message: const S(
                              'Your account has been disabled. Contact your '
                                  'school administrator for help.',
                              'حسابك متوقف. كلّم أدمن مدرستك.',
                              fr:
                                  'Votre compte a été désactivé. Contactez '
                                  "l'administrateur de votre école pour "
                                  "obtenir de l'aide.",
                              es:
                                  'Tu cuenta ha sido deshabilitada. '
                                  'Contacta con el administrador de tu '
                                  'escuela para obtener ayuda.',
                            ).of(context),
                            onSignOut: context.read<AuthCubit>().signOut,
                          ),
                          _ => _SignInForm(
                            formKey: _formKey,
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
            const PositionedDirectional(top: 12, end: 12, child: _TopControls()),
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
    final isLoading = state is AuthLoading;

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
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.family_restroom,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            const S(
              'Jammam School Bus',
              'تطبيق ولي الأمر',
              fr: 'Jammam School Bus',
              es: 'Jammam School Bus',
            ).of(context),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            registering
                ? const S(
                    'Create your parent account',
                    'اعمل حسابك كولي أمر',
                    fr: 'Créez votre compte parent',
                    es: 'Crea tu cuenta de padre/madre',
                  ).of(context)
                : const S(
                    'Welcome back',
                    'أهلاً بيك تاني',
                    fr: 'Ravi de vous revoir',
                    es: 'Bienvenido/a de nuevo',
                  ).of(context),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl2),
          if (registering)
            TextFormField(
              controller: name,
              decoration: InputDecoration(
                labelText: const S(
                  'Full name',
                  'الاسم بالكامل',
                  fr: 'Nom complet',
                  es: 'Nombre completo',
                ).of(context),
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? const S(
                      'Enter your name',
                      'اكتب اسمك',
                      fr: 'Entrez votre nom',
                      es: 'Introduce tu nombre',
                    ).of(context)
                  : null,
            ),
          if (registering) const SizedBox(height: AppSpacing.lg),
          if (registering)
            TextFormField(
              controller: schoolCode,
              decoration: InputDecoration(
                labelText: const S(
                  'School code',
                  'كود المدرسة',
                  fr: "Code de l'école",
                  es: 'Código de la escuela',
                ).of(context),
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? const S(
                      'Enter your school code',
                      'اكتب كود مدرستك',
                      fr: 'Entrez le code de votre école',
                      es: 'Introduce el código de tu escuela',
                    ).of(context)
                  : null,
            ),
          if (registering) const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: const S(
                'Email',
                'الإيميل',
                fr: 'E-mail',
                es: 'Correo electrónico',
              ).of(context),
            ),
            validator: (v) => (v ?? '').contains('@')
                ? null
                : const S(
                    'Enter a valid email',
                    'اكتب إيميل صحيح',
                    fr: 'Entrez un e-mail valide',
                    es: 'Introduce un correo electrónico válido',
                  ).of(context),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: password,
            obscureText: true,
            decoration: InputDecoration(
              labelText: const S(
                'Password',
                'كلمة السر',
                fr: 'Mot de passe',
                es: 'Contraseña',
              ).of(context),
            ),
            validator: (v) => registering
                ? ((v ?? '').length >= 8
                      ? null
                      : const S(
                          'Use at least 8 characters',
                          'لازم 8 حروف على الأقل',
                          fr: 'Utilisez au moins 8 caractères',
                          es: 'Usa al menos 8 caracteres',
                        ).of(context))
                : ((v ?? '').isEmpty
                      ? const S(
                          'Enter your password',
                          'اكتب كلمة السر',
                          fr: 'Entrez votre mot de passe',
                          es: 'Introduce tu contraseña',
                        ).of(context)
                      : null),
          ),
          const SizedBox(height: AppSpacing.xl2),
          AppButton.primary(
            label: registering
                ? const S(
                    'Create account',
                    'إنشاء الحساب',
                    fr: 'Créer un compte',
                    es: 'Crear cuenta',
                  ).of(context)
                : const S(
                    'Sign in',
                    'تسجيل الدخول',
                    fr: 'Se connecter',
                    es: 'Iniciar sesión',
                  ).of(context),
            onPressed: onSubmit,
            loading: isLoading,
          ),
          if (!registering)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: isLoading
                    ? null
                    : () => _showForgotPasswordDialog(context, email.text),
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
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: isLoading ? null : onToggleRegistering,
            child: Text(
              registering
                  ? const S(
                      'I already have an account',
                      'عندي حساب بالفعل',
                      fr: "J'ai déjà un compte",
                      es: 'Ya tengo una cuenta',
                    ).of(context)
                  : const S(
                      'Create a parent account',
                      'اعمل حساب ولي أمر',
                      fr: 'Créer un compte parent',
                      es: 'Crear una cuenta de padre/madre',
                    ).of(context),
            ),
          ),
          if (state is AuthSignedOut && (state as AuthSignedOut).message != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: ErrorStateView(
                compact: true,
                message: (state as AuthSignedOut).message!,
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
    required this.title,
    required this.message,
    required this.onSignOut,
  });

  final IconData icon;
  final StatusTone tone;
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
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: toneColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 32, color: toneColor),
        ),
        const SizedBox(height: AppSpacing.lg),
        StatusBadge(label: title, tone: tone),
        const SizedBox(height: AppSpacing.md),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton.secondary(
          label: const S(
            'Sign out',
            'تسجيل الخروج',
            fr: 'Se déconnecter',
            es: 'Cerrar sesión',
          ).of(context),
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
                  'Nous vous enverrons un lien par e-mail pour '
                  'réinitialiser votre mot de passe.',
              es: 'Te enviaremos un enlace por correo electrónico para '
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
        fr: 'Si $email a un compte, nous vous avons envoyé un lien de '
            'réinitialisation.',
        es: 'Si $email tiene una cuenta, te hemos enviado un enlace de '
            'restablecimiento.',
      ).of(context),
    );
  } catch (_) {
    if (!context.mounted) return;
    AppSnackbar.error(
      context,
      const S(
        "Couldn't send the reset email — try again.",
        'معرفناش نبعت إيميل الاستعادة — جرب تاني.',
        fr: "Impossible d'envoyer l'e-mail de réinitialisation — "
            'réessayez.',
        es: 'No se pudo enviar el correo de restablecimiento. Inténtalo '
            'de nuevo.',
      ).of(context),
    );
  }
}
