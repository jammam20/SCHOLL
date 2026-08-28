import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:school_shared/school_shared.dart';

import '../../common/presentation/location_picker_page.dart';
import '../../../widgets/async_error_view.dart';
import '../../legal/presentation/legal_page.dart';
import '../../schools/data/schools_repository.dart';
import '../data/profile_repository.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.user, required this.onSignOut});

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(const S('Profile', 'الملف الشخصي').of(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
                    user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: const S('Edit name', 'تعديل الاسم').of(context),
                      onPressed: () => _editName(context),
                    ),
                  ],
                ),
                if (user.email.isNotEmpty)
                  Text(user.email, style: TextStyle(color: colors.onSurfaceVariant)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
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
          const SizedBox(height: 28),
          Text(
            const S('My school', 'مدرستي').of(context),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _SchoolCard(schoolId: user.schoolId),
          const SizedBox(height: 28),
          Text(
            const S('Preferences', 'التفضيلات').of(context),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: Text(const S('Language', 'اللغة').of(context)),
                  subtitle: ValueListenableBuilder<Locale>(
                    valueListenable: AppSettings.locale,
                    builder: (context, locale, _) => Text(
                      locale.languageCode == 'ar' ? 'العربية' : 'English',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: AppSettings.toggleLocale,
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
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: onSignOut,
            style: OutlinedButton.styleFrom(foregroundColor: colors.error),
            icon: const Icon(Icons.logout),
            label: Text(const S('Sign out', 'تسجيل الخروج').of(context)),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(text: user.name);
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
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(const S('Save', 'حفظ').of(dialogContext)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    await ProfileRepository().updateName(schoolId: user.schoolId, name: name);
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
              padding: EdgeInsets.all(20),
              child: AsyncErrorView(compact: true),
            ),
          );
        }

        if (data == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isActive ? const Color(0xFF17B26A) : colors.error)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isActive
                            ? const S('Active', 'نشطة').of(context)
                            : const S('Inactive', 'غير نشطة').of(context),
                        style: TextStyle(
                          color: isActive ? const Color(0xFF17B26A) : colors.error,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Code: ${data['code'] ?? '-'}',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 18, color: colors.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        latitude == null || longitude == null
                            ? const S(
                                'Location not set — every trip needs this as its final stop.',
                                'الموقع لسه مش متحدد — كل رحلة محتاجة تنتهي هنا.',
                              ).of(context)
                            : 'Lat ${latitude.toStringAsFixed(5)}, '
                                  'Lng ${longitude.toStringAsFixed(5)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await Navigator.push<LatLng>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LocationPickerPage(
                              title: 'Set school location',
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
                        } on SchoolLocationException catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      },
                      child: Text(
                        latitude == null
                            ? const S('Set', 'تحديد').of(context)
                            : const S('Edit', 'تعديل').of(context),
                      ),
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
