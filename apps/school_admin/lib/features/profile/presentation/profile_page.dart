import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:school_shared/school_shared.dart';

import '../../../app/language_sync.dart';

import '../../common/presentation/location_picker_page.dart';
import '../../legal/presentation/legal_page.dart';
import '../../schools/data/schools_repository.dart';
import '../data/profile_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.user, required this.onSignOut});

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // See the parent app's ProfilePage for why this exists: without it, an
  // edited name only showed up on every *other* screen (each reads a fresh
  // live stream of its own) — this exact page had to wait for the auth
  // stream to round-trip back down through a rebuild from above, which
  // previously only actually happened after an app restart.
  late String _displayName = widget.user.name;

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user.name != oldWidget.user.name) {
      _displayName = widget.user.name;
    }
  }

  AppUser get user => widget.user;
  VoidCallback get onSignOut => widget.onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: Text(const S('Profile', 'الملف الشخصي').of(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xl3,
        ),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.primary, colors.tertiary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _displayName.isEmpty ? '?' : _displayName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: const S('Edit name', 'تعديل الاسم').of(context),
                      onPressed: () => _editName(context),
                    ),
                  ],
                ),
                if (user.email.isNotEmpty)
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      user.email,
                      style: TextStyle(color: appColors.textSecondary),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    const S('School administrator', 'مدير المدرسة').of(context),
                    style: TextStyle(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl3),
          SectionHeader(
            title: const S('My school', 'مدرستي').of(context),
          ),
          _SchoolCard(schoolId: user.schoolId),
          const SizedBox(height: AppSpacing.xl3),
          SectionHeader(
            title: const S('Operational settings', 'إعدادات التشغيل').of(context),
            subtitle: const S(
              'Enforced by the server, not just this screen.',
              'مطبقة من السيرفر، مش بس من الشاشة دي.',
            ).of(context),
          ),
          _OperationalSettingsCard(schoolId: user.schoolId),
          const SizedBox(height: AppSpacing.xl3),
          SectionHeader(
            title: const S('Preferences', 'التفضيلات').of(context),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: Text(const S('Language', 'اللغة', fr: 'Langue', es: 'Idioma').of(context)),
                  subtitle: ValueListenableBuilder<Locale>(
                    valueListenable: AppSettings.locale,
                    builder: (context, locale, _) =>
                        Text(AppLanguage.fromCode(locale.languageCode).nativeName),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      showLanguagePickerSheet(context, onChanged: LanguageSync.save),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: Text(const S('Dark mode', 'الوضع الليلي').of(context)),
                  trailing: ValueListenableBuilder<ThemeMode>(
                    valueListenable: AppSettings.themeMode,
                    builder: (context, mode, _) => Switch(
                      value: mode == ThemeMode.dark,
                      onChanged: (_) => AppSettings.toggleTheme(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(
                    const S('Privacy & Terms', 'الخصوصية والشروط').of(context),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LegalPage()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl3),
          AppButton.destructive(
            icon: Icons.logout,
            label: const S('Sign out', 'تسجيل الخروج').of(context),
            onPressed: onSignOut,
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(text: _displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(const S('Edit name', 'تعديل الاسم').of(dialogContext)),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(const S('Cancel', 'إلغاء').of(dialogContext)),
          ),
          AppButton.primary(
            label: const S('Save', 'حفظ').of(dialogContext),
            onPressed: () => Navigator.pop(dialogContext, controller.text),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    try {
      await ProfileRepository().updateName(schoolId: user.schoolId, name: trimmed);
      if (mounted) setState(() => _displayName = trimmed);
    } catch (_) {
      if (!context.mounted) return;
      AppSnackbar.error(
        context,
        const S(
          "Couldn't save your name — try again.",
          'معرفناش نحفظ اسمك — جرب تاني.',
        ).of(context),
      );
    }
  }
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: SchoolsRepository().watchSchool(schoolId),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final colors = Theme.of(context).colorScheme;

        if (snapshot.hasError) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: ErrorStateView(compact: true),
            ),
          );
        }

        if (data == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final latitude = (data['latitude'] as num?)?.toDouble();
        final longitude = (data['longitude'] as num?)?.toDouble();
        final isActive = data['isActive'] == true;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data['name']?.toString() ?? '',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    StatusBadge(
                      label: isActive
                          ? const S('Active', 'نشطة').of(context)
                          : const S('Inactive', 'غير نشطة').of(context),
                      tone: isActive ? StatusTone.success : StatusTone.error,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    'Code: ${data['code'] ?? '-'}',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
                const Divider(height: AppSpacing.xl2),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: latitude == null || longitude == null
                          ? Text(
                              const S(
                                'Location not set — every trip needs this as its final stop.',
                                'الموقع لسه مش متحدد — كل رحلة محتاجة تنتهي هنا.',
                              ).of(context),
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          : Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                'Lat ${latitude.toStringAsFixed(5)}, '
                                    'Lng ${longitude.toStringAsFixed(5)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppButton.secondary(
                      label: latitude == null
                          ? const S('Set', 'تحديد').of(context)
                          : const S('Edit', 'تعديل').of(context),
                      onPressed: () async {
                        final picked = await Navigator.push<LatLng>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LocationPickerPage(
                              title: const S(
                                'Set school location',
                                'تحديد موقع المدرسة',
                              ).of(context),
                              initialPosition: latitude == null || longitude == null
                                  ? null
                                  : LatLng(latitude, longitude),
                            ),
                          ),
                        );
                        if (picked == null) return;
                        try {
                          await SchoolsRepository().updateLocation(
                            schoolId: schoolId,
                            latitude: picked.latitude,
                            longitude: picked.longitude,
                          );
                          if (!context.mounted) return;
                          AppSnackbar.success(
                            context,
                            const S(
                              'School location updated.',
                              'تم تحديث موقع المدرسة.',
                            ).of(context),
                          );
                        } on SchoolLocationException catch (e) {
                          if (!context.mounted) return;
                          AppSnackbar.error(context, e.message);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Trip start window, absence cutoff, and calendar (Features: driver trip
/// start window, absence cutoff, school calendar) — all three are enforced
/// in firestore.rules directly (see `isWithinTripStartWindow`/
/// `isBeforeAbsenceCutoff`), this screen is just where an admin configures
/// the numbers those rules read.
class _OperationalSettingsCard extends StatelessWidget {
  const _OperationalSettingsCard({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: SchoolsRepository().watchSchool(schoolId),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        if (data == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        return _OperationalSettingsEditor(
          key: ValueKey(schoolId),
          schoolId: schoolId,
          school: School.fromMap(schoolId, data),
        );
      },
    );
  }
}

class _OperationalSettingsEditor extends StatefulWidget {
  const _OperationalSettingsEditor({
    super.key,
    required this.schoolId,
    required this.school,
  });

  final String schoolId;
  final School school;

  @override
  State<_OperationalSettingsEditor> createState() =>
      _OperationalSettingsEditorState();
}

class _OperationalSettingsEditorState
    extends State<_OperationalSettingsEditor> {
  late final _startWindow = TextEditingController(
    text: widget.school.tripStartWindowMinutes?.toString() ?? '',
  );
  late final _cutoff = TextEditingController(
    text: widget.school.absenceCutoffMinutes?.toString() ?? '',
  );
  final Set<int> _weeklyHolidays = {};

  @override
  void initState() {
    super.initState();
    _weeklyHolidays.addAll(widget.school.weeklyHolidays);
  }
  bool _saving = false;

  static const _weekdayLabels = [
    S('Mon', 'إثنين'),
    S('Tue', 'ثلاثاء'),
    S('Wed', 'أربعاء'),
    S('Thu', 'خميس'),
    S('Fri', 'جمعة'),
    S('Sat', 'سبت'),
    S('Sun', 'حد'),
  ];

  @override
  void dispose() {
    _startWindow.dispose();
    _cutoff.dispose();
    super.dispose();
  }

  Future<void> _pickSpecialHoliday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    final iso = isoDateOnly(picked);
    if (widget.school.specialHolidays.contains(iso)) return;
    await _save(
      specialHolidays: [...widget.school.specialHolidays, iso]..sort(),
    );
  }

  Future<void> _removeSpecialHoliday(String iso) async {
    await _save(
      specialHolidays:
          widget.school.specialHolidays.where((d) => d != iso).toList(),
    );
  }

  Future<void> _save({List<String>? specialHolidays}) async {
    setState(() => _saving = true);
    try {
      await SchoolsRepository().updateSettings(
        schoolId: widget.schoolId,
        tripStartWindowMinutes: int.tryParse(_startWindow.text.trim()),
        absenceCutoffMinutes: int.tryParse(_cutoff.text.trim()),
        weeklyHolidays: _weeklyHolidays.toList(),
        specialHolidays: specialHolidays ?? widget.school.specialHolidays,
      );
      if (!mounted) return;
      AppSnackbar.success(
        context,
        const S('Settings saved.', 'اتحفظت الإعدادات.').of(context),
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(
        context,
        const S(
          "Couldn't save these settings — try again.",
          'معرفناش نحفظ الإعدادات دي — جرب تاني.',
        ).of(context),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              const S('Driver trip start window', 'موعد بدء الرحلة للسواق')
                  .of(context),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              const S(
                'How many minutes before the scheduled time a driver may '
                    'start a trip. Leave blank to allow starting any time.',
                'قد إيه بالدقايق قبل الميعاد المحدد يقدر السواق يبدأ الرحلة. '
                    'سيبه فاضي عشان تسمح بالبدء في أي وقت.',
              ).of(context),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _startWindow,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffixText: const S('minutes', 'دقيقة').of(context),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              const S('Absence cutoff', 'موعد قفل الغياب').of(context),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              const S(
                'How many minutes before a route\'s outbound schedule a '
                    "parent may still mark their child absent for today. "
                    'Only applies to routes with an outbound time set. '
                    'Leave blank for no cutoff.',
                'قد إيه بالدقايق قبل ميعاد ذهاب الخط يقدر ولي الأمر يعلّم '
                    'ابنه غايب النهاردة. بتتطبق بس على الخطوط اللي ليها '
                    'ميعاد ذهاب محدد. سيبه فاضي عشان مفيش قفل.',
              ).of(context),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _cutoff,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffixText: const S('minutes', 'دقيقة').of(context),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              const S('Weekly holidays', 'الإجازات الأسبوعية').of(context),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (var weekday = 1; weekday <= 7; weekday++)
                  FilterChip(
                    label: Text(_weekdayLabels[weekday - 1].of(context)),
                    selected: _weeklyHolidays.contains(weekday),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _weeklyHolidays.add(weekday);
                      } else {
                        _weeklyHolidays.remove(weekday);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: Text(
                    const S('Special holidays', 'إجازات خاصة').of(context),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickSpecialHoliday,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(const S('Add date', 'إضافة تاريخ').of(context)),
                ),
              ],
            ),
            if (widget.school.specialHolidays.isNotEmpty)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final iso in widget.school.specialHolidays)
                    Chip(
                      label: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(iso),
                      ),
                      onDeleted: () => _removeSpecialHoliday(iso),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.xl),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AppButton.primary(
                label: const S('Save', 'حفظ').of(context),
                loading: _saving,
                onPressed: () => _save(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
