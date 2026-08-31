import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

import '../../../widgets/parent_ui.dart';

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
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          const S('Privacy & Terms', 'الخصوصية والشروط').of(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xl3,
        ),
        children: [
          InfoNotice(
            icon: Icons.shield_outlined,
            message: const S(
              'Your school runs this service and owns the data in it. '
                  "Anything you want reviewed, corrected or deleted goes "
                  "through your school's administrator.",
              'مدرستك هي اللي بتشغّل الخدمة دي وهي مالكة البيانات. أي حاجة '
                  'عايز تراجعها أو تصححها أو تمسحها بتتم عن طريق أدمن '
                  'مدرستك.',
            ).of(context),
          ),
          const SizedBox(height: AppSpacing.xl2),
          ...isArabic ? _arabicSections(context) : _englishSections(context),
        ],
      ),
    );
  }

  List<Widget> _englishSections(BuildContext context) => [
    _Section(
      icon: Icons.lock_outline_rounded,
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
    const SizedBox(height: AppSpacing.lg),
    _Section(
      icon: Icons.gavel_rounded,
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
      icon: Icons.lock_outline_rounded,
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
    const SizedBox(height: AppSpacing.lg),
    _Section(
      icon: Icons.gavel_rounded,
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
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md - 2),
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
