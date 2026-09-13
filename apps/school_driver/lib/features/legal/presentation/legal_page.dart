import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

/// Privacy policy and terms of use — required by app stores, and by basic
/// fairness given this app handles children's location and contact data.
/// Written to describe exactly what this app actually does (see the repos
/// this app writes to) rather than generic boilerplate. The school, not
/// this app's developer, is the data controller in this model — parents
/// and staff belong to one school's account — so requests are routed to
/// the school's own admin rather than to an app-wide support address.
///
/// The French and Spanish bodies are machine translations of the English
/// source and are pending native legal review; English and Arabic are the
/// authored versions.
class LegalPage extends StatelessWidget {
  const LegalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          const S('Privacy & Terms', 'الخصوصية والشروط', fr: 'Confidentialité et conditions', es: 'Privacidad y términos').of(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: _sections(context),
      ),
    );
  }

  List<Widget> _sections(BuildContext context) => [
    _Section(
      title: const S(
        'Privacy Policy',
        'سياسة الخصوصية',
        fr: 'Politique de confidentialité',
        es: 'Política de privacidad',
      ).of(context),
      body: const S(
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
        fr:
            "Cette application est utilisée par une seule école pour gérer son "
            "propre service de bus. Les données qu'elle collecte — le nom, "
            "l'e-mail et le téléphone d'un parent ou d'un membre du personnel ; "
            "le nom, la classe et le point de ramassage d'un élève ; et la "
            "position GPS en direct d'un bus pendant qu'un trajet est en cours "
            "— sont saisies par le personnel de votre école ou par vous-même, "
            "et ne sont visibles que par le personnel approuvé de votre propre "
            "école et par les parents liés à l'élève. Elles ne sont ni vendues, "
            "ni partagées avec des annonceurs, ni utilisées à d'autres fins que "
            "le fonctionnement du service de bus scolaire.\n\n"
            "Les données de localisation en direct ne sont diffusées que "
            "pendant qu'un trajet du conducteur est actif, et uniquement à "
            "l'école de ce trajet. Les jetons de notification push de "
            "l'appareil sont conservés afin que l'application puisse vous "
            "alerter au sujet du trajet de votre enfant ; vous pouvez les "
            "effacer en vous déconnectant.\n\n"
            "Pour consulter, corriger ou supprimer vos données, contactez "
            "l'administrateur de votre école — c'est lui qui gère votre compte "
            "et peut traiter la demande directement, puisque l'école (et non "
            "cette application) est propriétaire de ces données.",
        es:
            'Esta aplicación la utiliza un solo colegio para gestionar su '
            'propio servicio de autobús. Los datos que recopila — el nombre, el '
            'correo electrónico y el teléfono de un padre, madre o miembro del '
            'personal; el nombre, el curso y el punto de recogida de un alumno; '
            'y la ubicación GPS en directo de un autobús mientras un viaje está '
            'activo — los introduce el personal de su colegio o usted mismo, y '
            'solo son visibles para el personal aprobado de su propio colegio y '
            'para los padres vinculados al alumno. No se venden, ni se '
            'comparten con anunciantes, ni se usan para nada que no sea el '
            'funcionamiento del servicio de autobús escolar.\n\n'
            'Los datos de ubicación en directo solo se transmiten mientras el '
            'viaje de un conductor está activo, y únicamente al colegio de ese '
            'viaje. Los tokens de notificaciones push del dispositivo se '
            'almacenan para que la aplicación pueda avisarle sobre el viaje de '
            'su hijo; puede borrarlos cerrando sesión.\n\n'
            'Para consultar, corregir o eliminar sus datos, póngase en contacto '
            'con el administrador de su colegio — él gestiona su cuenta y puede '
            'atender la solicitud directamente, ya que el colegio (y no esta '
            'aplicación) es el propietario de esos datos.',
      ).of(context),
    ),
    const SizedBox(height: AppSpacing.xl2),
    _Section(
      title: const S(
        'Terms of Use',
        'شروط الاستخدام',
        fr: "Conditions d'utilisation",
        es: 'Términos de uso',
      ).of(context),
      body: const S(
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
        'الحسابات بتتوافق عليها مدرستك وممكن تتوقف أو تتشال حسب تقدير '
            'المدرسة. لازم بيانات الموقع ونقطة الاستلام تفضل صحيحة — نقطة '
            'استلام قديمة ممكن تخلي السواق يفوّت محطة الطالب. تحديد الطالب '
            'غايب معناه التزام إنه مش هيركب الأتوبيس النهاردة؛ استخدمها بس '
            'لما تكون متأكد، لأن خط سير السواق بيتعدل على أساسها.\n\n'
            'الخدمة دي متاحة زي ما هي عشان تنظيم مواصلات المدرسة، ومش بديل '
            'عن التواصل المباشر مع المدرسة في حالة الطوارئ.',
        fr:
            "Les comptes sont approuvés par votre école et peuvent être "
            "suspendus ou supprimés par celle-ci à sa discrétion. Les "
            "informations de localisation et de point de ramassage doivent "
            "rester exactes — un point de ramassage périmé peut amener le "
            "conducteur à manquer l'arrêt d'un élève. Marquer un élève absent "
            "est un engagement qu'il ne prendra pas le bus ce jour-là ; ne "
            "l'utilisez que lorsque c'est exact, car l'itinéraire du conducteur "
            "est ajusté en conséquence.\n\n"
            "Ce service est fourni en l'état pour coordonner le transport "
            "scolaire et ne remplace pas une communication directe avec "
            "l'école en cas d'urgence.",
        es:
            'Las cuentas las aprueba su colegio y pueden ser suspendidas o '
            'eliminadas por el colegio a su discreción. La información de '
            'ubicación y del punto de recogida debe mantenerse actualizada — un '
            'punto de recogida desfasado puede hacer que el conductor se salte '
            'la parada de un alumno. Marcar a un alumno como ausente es un '
            'compromiso de que ese día no viajará; úselo solo cuando sea '
            'exacto, ya que la ruta del conductor se ajusta en función de '
            'ello.\n\n'
            'Este servicio se presta tal cual para coordinar el transporte '
            'escolar y no sustituye a la comunicación directa con el colegio en '
            'caso de emergencia.',
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
