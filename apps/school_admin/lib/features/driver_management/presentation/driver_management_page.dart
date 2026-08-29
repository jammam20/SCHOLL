import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../../common/presentation/domain_labels.dart';
import '../../drivers/data/drivers_repository.dart';
import '../data/driver_profiles_repository.dart';
import 'bloc/driver_management_bloc.dart';
import 'driver_detail_page.dart';

/// The driver roster with each driver's licensing status front and centre
/// — the operational counterpart to the People > Drivers tab, which stays
/// focused purely on approve/suspend/reject membership actions.
class DriverManagementPage extends StatelessWidget {
  const DriverManagementPage({
    super.key,
    required this.schoolId,
    this.readOnly = false,
    this.showAppBar = true,
  });

  final String schoolId;
  final bool readOnly;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          DriverManagementBloc(DriversRepository(), DriverProfilesRepository())
            ..add(DriverManagementStarted(schoolId)),
      child: _DriverManagementView(
        schoolId: schoolId,
        readOnly: readOnly,
        showAppBar: showAppBar,
      ),
    );
  }
}

class _DriverManagementView extends StatelessWidget {
  const _DriverManagementView({
    required this.schoolId,
    required this.readOnly,
    required this.showAppBar,
  });

  final String schoolId;
  final bool readOnly;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DriverManagementBloc, DriverManagementState>(
      listenWhen: (_, current) =>
          current is DriverManagementLoaded && current.actionError != null,
      listener: (context, state) {
        if (state is DriverManagementLoaded && state.actionError != null) {
          AppSnackbar.error(context, state.actionError!);
        }
      },
      builder: (context, state) {
        Widget body;

        if (state is DriverManagementLoading ||
            state is DriverManagementInitial) {
          body = ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 6,
            itemBuilder: (_, _) => const AppSkeletonListTile(),
          );
        } else if (state is DriverManagementFailure) {
          body = ErrorStateView(
            message: state.message,
            onRetry: () => context.read<DriverManagementBloc>().add(
              DriverManagementStarted(schoolId),
            ),
          );
        } else {
          final drivers = (state as DriverManagementLoaded).drivers;
          body = drivers.isEmpty
              ? EmptyStateView(
                  icon: Icons.badge_outlined,
                  title: const S(
                    'No drivers found',
                    'مفيش سائقين',
                  ).of(context),
                  message: const S(
                    'Drivers appear here once they sign up and request to '
                        'join your school.',
                    'السواقين هيظهروا هنا لما يسجلوا ويطلبوا الانضمام '
                        'لمدرستك.',
                  ).of(context),
                )
              : _DriverRoster(
                  schoolId: schoolId,
                  drivers: drivers,
                  readOnly: readOnly,
                );
        }

        return Scaffold(
          appBar: showAppBar
              ? AppBar(
                  title: Text(
                    const S('Drivers', 'إدارة السائقين').of(context),
                  ),
                )
              : null,
          body: body,
        );
      },
    );
  }
}

class _DriverRoster extends StatelessWidget {
  const _DriverRoster({
    required this.schoolId,
    required this.drivers,
    required this.readOnly,
  });

  final String schoolId;
  final List<DriverWithProfile> drivers;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final now = DateTime.now();

    final expired = drivers.where((d) => d.licenseExpired).length;
    final expiringSoon = drivers
        .where((d) => !d.licenseExpired && d.licenseExpiringSoon(now))
        .length;
    final noLicenseRecorded = drivers
        .where((d) => d.profile?.licenseExpiry == null)
        .length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xl3,
          ),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = AppSpacing.md;
                final columns = constraints.maxWidth >= 900 ? 4 : 2;
                final cardWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                final cards = [
                  MetricStatCard(
                    icon: Icons.groups_outlined,
                    label: const S('Drivers', 'السائقين').of(context),
                    value: '${drivers.length}',
                  ),
                  MetricStatCard(
                    icon: Icons.gpp_bad_outlined,
                    tone: expired > 0 ? colors.error : colors.success,
                    label: const S(
                      'Expired licenses',
                      'رخص منتهية',
                    ).of(context),
                    value: '$expired',
                  ),
                  MetricStatCard(
                    icon: Icons.hourglass_bottom,
                    tone: expiringSoon > 0 ? colors.warning : colors.success,
                    label: const S(
                      'Expiring in 14 days',
                      'هتنتهي خلال 14 يوم',
                    ).of(context),
                    value: '$expiringSoon',
                  ),
                  MetricStatCard(
                    icon: Icons.help_outline,
                    tone: colors.info,
                    label: const S(
                      'No license recorded',
                      'من غير رخصة مسجلة',
                    ).of(context),
                    value: '$noLicenseRecorded',
                  ),
                ];
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final card in cards)
                      SizedBox(width: cardWidth, child: card),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl2),
            SectionHeader(
              title: const S('Roster', 'قائمة السائقين').of(context),
              subtitle: const S(
                'Drivers needing licence attention are listed first. Open a '
                    'driver to edit their profile and see their trip record.',
                'السواقين اللي رخصهم محتاجة انتباه بيظهروا الأول. افتح '
                    'السائق عشان تعدّل بياناته وتشوف سجل رحلاته.',
              ).of(context),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = AppSpacing.md;
                final columns = constraints.maxWidth >= 1080
                    ? 3
                    : constraints.maxWidth >= 720
                    ? 2
                    : 1;
                final cardWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final driver in drivers)
                      SizedBox(
                        width: cardWidth,
                        child: _DriverCard(
                          key: ValueKey(driver.uid),
                          schoolId: schoolId,
                          driver: driver,
                          readOnly: readOnly,
                          now: now,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    super.key,
    required this.schoolId,
    required this.driver,
    required this.readOnly,
    required this.now,
  });

  final String schoolId;
  final DriverWithProfile driver;
  final bool readOnly;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final profile = driver.profile;
    final flagged = driver.needsAttention(now);
    final trainingCompletedAt = profile?.trainingCompletedAt;
    final trainedOn = trainingCompletedAt == null
        ? null
        : DateFormat.yMMMd().format(trainingCompletedAt);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: readOnly
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DriverDetailPage(
                  schoolId: schoolId,
                  uid: driver.uid,
                  displayName: driver.displayName,
                ),
              ),
            ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: flagged
                ? (driver.licenseExpired ? colors.error : colors.warning)
                      .withValues(alpha: 0.45)
                : colors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.surfaceElevated,
                  foregroundColor: colors.textSecondary,
                  child: const Icon(Icons.badge),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.displayName,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      StatusBadge(
                        label: driver.isApproved
                            ? const S('Approved', 'مقبول').of(context)
                            : driver.status,
                        tone: driver.isApproved
                            ? StatusTone.success
                            : StatusTone.warning,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _LicenseLine(driver: driver, now: now),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.school_outlined, size: 14, color: colors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    trainedOn == null
                        ? const S(
                            'Training not recorded',
                            'التدريب مش مسجل',
                          ).of(context)
                        : S('Trained $trainedOn', 'اتدرب $trainedOn').of(
                            context,
                          ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 14,
                  color: colors.textMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    S(
                      '${profile?.assignedBusIds.length ?? 0} bus(es) · '
                          '${profile?.assignedRouteIds.length ?? 0} route(s) '
                          'assigned',
                      '${profile?.assignedBusIds.length ?? 0} أتوبيس · '
                          '${profile?.assignedRouteIds.length ?? 0} خط مخصص',
                    ).of(context),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The spec's "License expires in N days" alert, computed with
/// [DriverProfile.licenseExpiringWithin] over a 14-day window.
class _LicenseLine extends StatelessWidget {
  const _LicenseLine({required this.driver, required this.now});

  final DriverWithProfile driver;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final expiry = driver.profile?.licenseExpiry;

    if (expiry == null) {
      return Row(
        children: [
          Icon(Icons.credit_card_off_outlined, size: 14, color: colors.textMuted),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              const S(
                'No licence expiry recorded',
                'تاريخ انتهاء الرخصة مش مسجل',
              ).of(context),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
              ),
            ),
          ),
        ],
      );
    }

    final days = DateTime(expiry.year, expiry.month, expiry.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;

    final tone = driver.licenseExpired
        ? StatusTone.error
        : driver.licenseExpiringSoon(now)
        ? StatusTone.warning
        : StatusTone.success;

    return Row(
      children: [
        Icon(Icons.credit_card, size: 14, color: toneColor(colors, tone)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            driver.licenseExpired
                ? S(
                    'Licence expired ${-days} day(s) ago',
                    'الرخصة انتهت من ${-days} يوم',
                  ).of(context)
                : S(
                    'Licence expires in $days day(s)',
                    'الرخصة هتنتهي خلال $days يوم',
                  ).of(context),
            style: theme.textTheme.bodySmall?.copyWith(
              color: toneColor(colors, tone),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
