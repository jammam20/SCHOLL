import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

/// Privacy policy and terms of use for the platform-owner panel. Unlike
/// the school-facing apps (where each school is its own data controller),
/// this app's operator is the platform itself, since it's the one creating
/// school accounts and approving their first admin.
class LegalPage extends StatelessWidget {
  const LegalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          const S(
            'Privacy & Terms',
            'الخصوصية والشروط',
            fr: 'Confidentialité et conditions',
            es: 'Privacidad y términos',
          ).of(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: _sections(context),
      ),
    );
  }

  // Previously two parallel `_arabicSections()` / `_englishSections()`
  // functions picked by an `isArabic` bool — that shape only had room for
  // two languages. A single function resolving each string through the
  // shared localization helper covers all four, the same way the rest of
  // the app does.
  List<Widget> _sections(BuildContext context) => [
    _Section(
      title: const S(
        'Privacy Policy',
        'سياسة الخصوصية',
        fr: 'Politique de confidentialité',
        es: 'Política de privacidad',
      ).of(context),
      body: const S(
        'This panel manages the platform that hosts every school using '
            'the school-bus apps. The data it handles here — a school\'s '
            "name and join code, and a prospective admin's name and email "
            'during approval — exists only to create and activate school '
            "accounts. It isn't shared with third parties or used for "
            "advertising. Each school's own operational data (its "
            "students, parents, drivers, and trips) belongs to that school "
            'and is not accessible from this panel beyond counts and '
            'approval status.\n\n'
            'System-admin accounts on this panel are created directly, not '
            'through self-registration, and are reviewed by the platform '
            'owner.',
        'اللوحة دي بتدير المنصة اللي بتستضيف كل المدارس اللي بتستخدم '
            'تطبيقات الأتوبيس. البيانات اللي بتتعامل معاها هنا — اسم '
            'المدرسة وكود الانضمام، واسم وإيميل الأدمن المرشح وقت الموافقة '
            '— موجودة بس عشان إنشاء وتفعيل حسابات المدارس. مش بتتشارك مع '
            'أي جهة تالتة ولا بتتستخدم في إعلانات. البيانات التشغيلية '
            'الخاصة بكل مدرسة (طلابها وأولياء أمورها وسواقينها ورحلاتها) '
            'ملك المدرسة نفسها ومش متاحة من اللوحة دي غير كأعداد وحالة '
            'الموافقة بس.\n\n'
            'حسابات المشرف العام على اللوحة دي بتتعمل يدويًا، مش بالتسجيل '
            'الذاتي، ومراجعة من مالك المنصة.',
        fr:
            "Ce panneau gère la plateforme qui héberge toutes les écoles "
            "utilisant les applications de bus scolaire. Les données "
            "traitées ici — le nom et le code d'inscription d'une école, "
            "ainsi que le nom et l'e-mail d'un administrateur potentiel "
            "pendant l'approbation — servent uniquement à créer et activer "
            "les comptes des écoles. Elles ne sont partagées avec aucun "
            "tiers ni utilisées à des fins publicitaires. Les données "
            "opérationnelles propres à chaque école (ses élèves, parents, "
            "chauffeurs et trajets) appartiennent à cette école et ne sont "
            "accessibles depuis ce panneau que sous forme de totaux et de "
            "statut d'approbation.\n\n"
            "Les comptes administrateur système de ce panneau sont créés "
            "directement, sans auto-inscription, et sont examinés par le "
            "propriétaire de la plateforme.",
        es:
            'Este panel gestiona la plataforma que aloja a todas las '
            'escuelas que utilizan las aplicaciones de bus escolar. Los '
            'datos que se gestionan aquí —el nombre y el código de '
            'inscripción de una escuela, así como el nombre y el correo '
            'electrónico de un posible administrador durante la '
            'aprobación— existen únicamente para crear y activar las '
            'cuentas de las escuelas. No se comparten con terceros ni se '
            'utilizan con fines publicitarios. Los datos operativos '
            'propios de cada escuela (sus estudiantes, padres, '
            'conductores y viajes) pertenecen a esa escuela y no son '
            'accesibles desde este panel más allá de los recuentos y el '
            'estado de aprobación.\n\n'
            'Las cuentas de administrador del sistema en este panel se '
            'crean directamente, no mediante autorregistro, y son '
            'revisadas por el propietario de la plataforma.',
      ).of(context),
    ),
    const SizedBox(height: AppSpacing.xl3),
    _Section(
      title: const S(
        'Terms of Use',
        'شروط الاستخدام',
        fr: "Conditions d'utilisation",
        es: 'Términos de uso',
      ).of(context),
      body: const S(
        'Access to this panel is restricted to the platform owner and '
            'anyone they explicitly grant it to. Actions here — activating '
            'or deactivating a school, approving its first admin — have '
            'real consequences for that school\'s staff and families, and '
            'should be taken deliberately.',
        'الدخول للوحة دي مقصور على مالك المنصة وأي حد يديله صلاحية '
            'صريحة. الإجراءات هنا — تفعيل أو تعطيل مدرسة، الموافقة على '
            'أول أدمن ليها — ليها نتايج حقيقية على موظفي وعائلات المدرسة '
            'دي، فلازم تتاخد بحرص.',
        fr:
            "L'accès à ce panneau est réservé au propriétaire de la "
            "plateforme et à toute personne à qui il l'accorde "
            "explicitement. Les actions effectuées ici — activer ou "
            "désactiver une école, approuver son premier administrateur — "
            "ont de réelles conséquences pour le personnel et les familles "
            "de cette école, et doivent être prises avec réflexion.",
        es:
            'El acceso a este panel está restringido al propietario de la '
            'plataforma y a cualquier persona a quien se lo conceda '
            'explícitamente. Las acciones realizadas aquí —activar o '
            'desactivar una escuela, aprobar a su primer administrador— '
            'tienen consecuencias reales para el personal y las familias '
            'de esa escuela, y deben tomarse de manera deliberada.',
      ).of(context),
    ),
  ];
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl2),
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: appColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
