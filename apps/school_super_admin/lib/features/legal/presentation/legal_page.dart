import 'package:flutter/material.dart';

import '../../../app/app_settings.dart';

/// Privacy policy and terms of use for the platform-owner panel. Unlike
/// the school-facing apps (where each school is its own data controller),
/// this app's operator is the platform itself, since it's the one creating
/// school accounts and approving their first admin.
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
        padding: const EdgeInsets.all(20),
        children: isArabic ? _arabicSections(context) : _englishSections(context),
      ),
    );
  }

  List<Widget> _englishSections(BuildContext context) => [
    _Section(
      title: 'Privacy Policy',
      body:
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
    ),
    const SizedBox(height: 24),
    _Section(
      title: 'Terms of Use',
      body:
          'Access to this panel is restricted to the platform owner and '
          'anyone they explicitly grant it to. Actions here — activating '
          'or deactivating a school, approving its first admin — have '
          'real consequences for that school\'s staff and families, and '
          'should be taken deliberately.',
    ),
  ];

  List<Widget> _arabicSections(BuildContext context) => [
    _Section(
      title: 'سياسة الخصوصية',
      body:
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
    ),
    const SizedBox(height: 24),
    _Section(
      title: 'شروط الاستخدام',
      body:
          'الدخول للوحة دي مقصور على مالك المنصة وأي حد يديله صلاحية '
          'صريحة. الإجراءات هنا — تفعيل أو تعطيل مدرسة، الموافقة على '
          'أول أدمن ليها — ليها نتايج حقيقية على موظفي وعائلات المدرسة '
          'دي، فلازم تتاخد بحرص.',
    ),
  ];
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(body, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
