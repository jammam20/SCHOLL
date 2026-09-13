import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

/// Privacy policy and terms of use — required by app stores, and by basic
/// fairness given this app handles children's location and contact data.
/// Written to describe exactly what this app actually does (see the repos
/// this app writes to) rather than generic boilerplate. The school, not
/// this app's developer, is the data controller in this model — parents
/// and staff belong to one school's account — so requests are routed to
/// the school's own admin rather than to an app-wide support address.
class LegalPage extends StatelessWidget {
  const LegalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
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
        children: switch (languageCode) {
          'ar' => _arabicSections(context),
          'fr' => _frenchSections(context),
          'es' => _spanishSections(context),
          _ => _englishSections(context),
        },
      ),
    );
  }

  List<Widget> _englishSections(BuildContext context) => [
    _Section(
      title: 'Privacy Policy',
      body:
          'This app is used by one school to run its own bus service. The '
          "data it collects — a parent's or staff member's name, email, and "
          "phone; a student's name, grade, and pickup location; and a bus's "
          'live GPS location while a trip is active — is entered by your '
          "school's staff or by you, and is visible only to your own "
          "school's approved staff and to a student's linked parents. It "
          "isn't sold, shared with advertisers, or used for anything beyond "
          'running the school bus service.\n\n'
          "Live location data is only broadcast while a driver's trip is "
          "active, and only to that trip's own school. Device push-"
          'notification tokens are stored so the app can alert you about '
          "your child's trip; you can clear this by signing out.\n\n"
          "To review, correct, or delete your data, contact your school's "
          'administrator — they manage your account and can action the '
          'request directly, since the school (not this app) is the owner '
          'of that data.',
    ),
    const SizedBox(height: AppSpacing.xl2),
    _Section(
      title: 'Terms of Use',
      body:
          'Accounts are approved by your school and may be suspended or '
          'removed by your school at its discretion. Location and pickup-'
          'point information should be kept accurate — an out-of-date '
          "pickup point can cause the driver to miss a student's stop. "
          "Marking a student absent is a commitment that they won't be "
          'riding that day; please only use it when accurate, since the '
          "driver's route is adjusted based on it.\n\n"
          'This service is provided as-is for coordinating school '
          'transportation and is not a substitute for direct communication '
          'with the school in an emergency.',
    ),
  ];

  List<Widget> _arabicSections(BuildContext context) => [
    _Section(
      title: 'سياسة الخصوصية',
      body:
          'التطبيق ده بتستخدمه مدرسة واحدة عشان تدير خدمة الأتوبيس بتاعتها. '
          'البيانات اللي بيجمعها — اسم وإيميل وتليفون ولي الأمر أو الموظف؛ '
          'واسم وصف ونقطة استلام الطالب؛ وموقع الأتوبيس اللحظي وقت الرحلة '
          'بس — بيدخّلها موظفين المدرسة أو إنت نفسك، ومش بتتشاف إلا من '
          'موظفي مدرستك المعتمدين وأولياء أمور الطالب المرتبطين بيه. '
          'البيانات دي مش بتتباع ولا بتتشارك مع أي جهة إعلانات، ومش '
          'بتتستخدم في أي حاجة غير تشغيل خدمة الأتوبيس.\n\n'
          'الموقع اللحظي بيتبث بس وقت ما رحلة السواق شغالة، وبيوصل بس '
          'لمدرسة الرحلة دي. بيتخزن كود إشعارات الجهاز عشان التطبيق ينبهك '
          'على رحلة ابنك؛ تقدر تمسحه بتسجيل الخروج.\n\n'
          'عشان تراجع أو تصحح أو تمسح بياناتك، كلّم أدمن مدرستك — هو اللي '
          'بيدير حسابك ويقدر ينفذ الطلب مباشرة، لأن المدرسة (مش التطبيق) '
          'هي مالكة البيانات دي.',
    ),
    const SizedBox(height: AppSpacing.xl2),
    _Section(
      title: 'شروط الاستخدام',
      body:
          'الحسابات بتتوافق عليها مدرستك وممكن تتوقف أو تتشال حسب تقدير '
          'المدرسة. لازم بيانات الموقع ونقطة الاستلام تفضل صحيحة — نقطة '
          'استلام قديمة ممكن تخلي السواق يفوّت محطة الطالب. تحديد الطالب '
          'غايب معناه التزام إنه مش هيركب الأتوبيس النهاردة؛ استخدمها بس '
          'لما تكون متأكد، لأن خط سير السواق بيتعدل على أساسها.\n\n'
          'الخدمة دي متاحة زي ما هي عشان تنظيم مواصلات المدرسة، ومش بديل '
          'عن التواصل المباشر مع المدرسة في حالة الطوارئ.',
    ),
  ];

  List<Widget> _frenchSections(BuildContext context) => [
    _Section(
      title: 'Politique de confidentialité',
      body: '''Cette application est utilisée par une seule école pour gérer son propre service de bus. Les données qu'elle collecte — le nom, l'e-mail et le téléphone d'un parent ou d'un membre du personnel ; le nom, la classe et le point de ramassage d'un élève ; ainsi que la position GPS en temps réel d'un bus pendant qu'une course est en cours — sont saisies par le personnel de votre école ou par vous-même, et ne sont visibles que par le personnel agréé de votre propre école et par les parents liés à un élève. Elles ne sont ni vendues, ni partagées avec des annonceurs, ni utilisées à d'autres fins que la gestion du service de bus scolaire.

La position en temps réel n'est diffusée que pendant qu'une course d'un chauffeur est en cours, et uniquement à l'école concernée par cette course. Les jetons de notification push de l'appareil sont conservés afin que l'application puisse vous alerter au sujet du trajet de votre enfant ; vous pouvez les effacer en vous déconnectant.

Pour consulter, corriger ou supprimer vos données, contactez l'administrateur de votre école — il gère votre compte et peut traiter la demande directement, l'école (et non cette application) étant responsable de ces données.''',
    ),
    const SizedBox(height: AppSpacing.xl2),
    _Section(
      title: "Conditions d'utilisation",
      body: '''Les comptes sont approuvés par votre école et peuvent être suspendus ou supprimés par celle-ci à sa discrétion. Les informations de localisation et de point de ramassage doivent rester à jour — un point de ramassage périmé peut amener le chauffeur à manquer l'arrêt d'un élève. Signaler l'absence d'un élève revient à confirmer qu'il ne montera pas dans le bus ce jour-là ; merci de ne l'utiliser que lorsque c'est exact, car l'itinéraire du chauffeur est ajusté en fonction de cette information.

Ce service est fourni tel quel pour coordonner le transport scolaire et ne remplace pas une communication directe avec l'école en cas d'urgence.''',
    ),
  ];

  List<Widget> _spanishSections(BuildContext context) => [
    _Section(
      title: 'Política de privacidad',
      body: '''Esta aplicación la utiliza un único colegio para gestionar su propio servicio de autobús. Los datos que recopila — el nombre, correo electrónico y teléfono de un padre/madre o miembro del personal; el nombre, curso y punto de recogida de un alumno; y la ubicación GPS en tiempo real de un autobús mientras un viaje está en curso — los introduce el personal de tu colegio o tú mismo, y solo son visibles para el personal autorizado de tu propio colegio y para los padres vinculados a un alumno. No se venden, no se comparten con anunciantes ni se usan para nada que no sea gestionar el servicio de autobús escolar.

La ubicación en tiempo real solo se transmite mientras el viaje de un conductor está activo, y únicamente al colegio de ese viaje. Se almacenan los tokens de notificaciones push del dispositivo para que la aplicación pueda avisarte sobre el viaje de tu hijo o hija; puedes borrarlos cerrando sesión.

Para revisar, corregir o eliminar tus datos, contacta con el administrador de tu colegio: gestiona tu cuenta y puede tramitar la solicitud directamente, ya que el colegio (y no esta aplicación) es el responsable de esos datos.''',
    ),
    const SizedBox(height: AppSpacing.xl2),
    _Section(
      title: 'Términos de uso',
      body: '''Las cuentas son aprobadas por tu colegio y este puede suspenderlas o eliminarlas a su discreción. La información de ubicación y del punto de recogida debe mantenerse actualizada: un punto de recogida desactualizado puede hacer que el conductor se salte la parada de un alumno. Marcar a un alumno como ausente es un compromiso de que no viajará ese día; utilízalo solo cuando sea exacto, ya que la ruta del conductor se ajusta en función de ello.

Este servicio se ofrece tal cual para coordinar el transporte escolar y no sustituye la comunicación directa con el colegio en caso de emergencia.''',
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
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
