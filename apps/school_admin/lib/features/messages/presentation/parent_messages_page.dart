import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

import '../data/parent_messages_repository.dart';
import 'admin_thread_page.dart';

/// The admin inbox for parent conversations (Feature: Parent-Driver
/// communication) — this is the surface that was entirely missing before:
/// a parent could send a message with nowhere for the school to read it.
class ParentMessagesPage extends StatelessWidget {
  const ParentMessagesPage({super.key, required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          const S(
            'Parent messages',
            'رسايل أولياء الأمور',
            fr: 'Messages des parents',
            es: 'Mensajes de los padres',
          ).of(context),
        ),
      ),
      body: StreamBuilder<List<ParentRequest>>(
        stream: ParentMessagesRepository().watchThreads(schoolId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: const [
                AppSkeletonListTile(),
                AppSkeletonListTile(),
                AppSkeletonListTile(),
              ],
            );
          }
          if (snapshot.hasError) {
            return const ErrorStateView();
          }

          final threads = snapshot.data ?? const <ParentRequest>[];
          if (threads.isEmpty) {
            return EmptyStateView(
              icon: Icons.forum_outlined,
              title: const S(
                'No messages yet',
                'مفيش رسايل لسه',
                fr: 'Aucun message pour le moment',
                es: 'Aún no hay mensajes',
              ).of(context),
              message: const S(
                "Parents' messages to the school will show up here.",
                'رسايل أولياء الأمور للمدرسة هتظهر هنا.',
                fr: "Les messages des parents à l'école apparaîtront ici.",
                es: 'Los mensajes de los padres al colegio aparecerán aquí.',
              ).of(context),
            );
          }

          final open = threads
              .where((t) => t.status != ParentRequestStatus.closed)
              .toList();
          final closed = threads
              .where((t) => t.status == ParentRequestStatus.closed)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (open.isNotEmpty) ...[
                SectionHeader(
                  title: const S(
                    'Open',
                    'مفتوحة',
                    fr: 'Ouvertes',
                    es: 'Abiertas',
                  ).of(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final thread in open)
                  _ThreadTile(schoolId: schoolId, request: thread),
              ],
              if (closed.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl2),
                SectionHeader(
                  title: const S(
                    'Closed',
                    'مقفولة',
                    fr: 'Fermées',
                    es: 'Cerradas',
                  ).of(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final thread in closed)
                  _ThreadTile(schoolId: schoolId, request: thread),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.schoolId, required this.request});

  final String schoolId;
  final ParentRequest request;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final unread = request.unreadByAdmin;
    final lastActivity = request.lastMessageAt ?? request.createdAt;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminThreadPage(schoolId: schoolId, request: request),
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: unread
              ? colors.info.withValues(alpha: 0.15)
              : colors.surfaceElevated,
          child: Icon(
            Icons.person_outline,
            color: unread ? colors.info : colors.textMuted,
          ),
        ),
        title: Text(
          request.subject.isEmpty
              ? const S(
                  'General question',
                  'سؤال عام',
                  fr: 'Question générale',
                  es: 'Pregunta general',
                ).of(context)
              : request.subject,
          style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600),
        ),
        subtitle: Text(
          request.lastMessagePreview ?? request.message,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: unread ? colors.textPrimary : colors.textSecondary,
            fontWeight: unread ? FontWeight.w600 : null,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              DateFormat.MMMd().format(lastActivity),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
              ),
            ),
            if (unread) ...[
              const SizedBox(height: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: colors.info, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
