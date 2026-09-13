import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../features/audit/data/audit_log_repository.dart';
import '../features/audit/presentation/audit_trail_page.dart';
import '../features/common/presentation/domain_labels.dart';

/// A compact "what's happened to this record" list for a student/parent/
/// driver detail view — reusing the exact same `auditLog` collection and
/// label/tone helpers the full Audit trail page already reads, filtered
/// down to entries about *this* entity. Deliberately not a second audit
/// system: there is no separate write path or model here, only a
/// client-side filter over the one stream `AuditLogRepository` already
/// exposes (the same "filter client-side over one indexed stream" approach
/// `AuditTrailPage` itself uses).
class ActivityTimeline extends StatelessWidget {
  const ActivityTimeline({
    super.key,
    required this.schoolId,
    required this.matches,
    this.maxItems = 8,
    this.showViewAllLink = true,
  });

  final String schoolId;

  /// Which audit entries belong to this entity — e.g.
  /// `(entry) => entry.studentId == studentId || entry.entityId == studentId`.
  final bool Function(AuditLogEntry entry) matches;
  final int maxItems;
  final bool showViewAllLink;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // A generous limit over the school's whole log, client-filtered —
      // matches AuditTrailPage's own approach, and is cheap enough for a
      // detail view that only needs the most recent handful anyway.
      stream: AuditLogRepository().watchAuditLog(schoolId, limit: 300),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const ErrorStateView(compact: true);
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              children: [
                AppSkeletonListTile(),
                AppSkeletonListTile(),
              ],
            ),
          );
        }

        final entries = snapshot.data!.docs
            .map((doc) => AuditLogEntry.fromMap(doc.id, doc.data()))
            .where(matches)
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        if (entries.isEmpty) {
          return EmptyStateView(
            compact: true,
            icon: Icons.history_outlined,
            title: const S(
              'No recorded activity yet',
              'مفيش نشاط مسجل لسه',
              fr: 'Aucune activité enregistrée pour le moment',
              es: 'Aún no hay actividad registrada',
            ).of(context),
          );
        }

        final visible = entries.take(maxItems).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < visible.length; i++)
              _TimelineRow(
                entry: visible[i],
                isLast: i == visible.length - 1,
              ),
            if (showViewAllLink && entries.length > visible.length) ...[
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AuditTrailPage(schoolId: schoolId),
                  ),
                ),
                child: Text(
                  S(
                    'View all ${entries.length} in the audit trail',
                    'عرض كل الـ ${entries.length} في سجل التدقيق',
                    fr: "Voir les ${entries.length} entrées du journal d'audit",
                    es: 'Ver las ${entries.length} entradas del registro de auditoría',
                  ).of(context),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.isLast});

  final AuditLogEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final tone = auditActionTone(entry.action);
    final accent = toneColor(colors, tone);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: colors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    auditActionLabel(entry.action, context),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _relativeWhen(context, entry.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _relativeWhen(BuildContext context, DateTime timestamp) {
    final now = DateTime.now();
    final isToday =
        timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        timestamp.year == yesterday.year &&
        timestamp.month == yesterday.month &&
        timestamp.day == yesterday.day;
    if (isToday) return DateFormat.jm().format(timestamp);
    if (isYesterday) {
      return S(
        'Yesterday · ${DateFormat.jm().format(timestamp)}',
        'إمبارح · ${DateFormat.jm().format(timestamp)}',
        fr: 'Hier · ${DateFormat.jm().format(timestamp)}',
        es: 'Ayer · ${DateFormat.jm().format(timestamp)}',
      ).of(context);
    }
    return DateFormat.yMMMd().add_jm().format(timestamp);
  }
}
