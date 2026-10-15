import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';

class NotificationsCenterScreen extends ConsumerWidget {
  const NotificationsCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(notificationsProvider);

    return AppScaffold(
      title: 'Notifications',
      subtitle: '${notifs.where((n) => !n.read).length} non lues',
      actions: [
        if (notifs.isNotEmpty)
          TextButton(
            onPressed: () => ref.read(notificationsProvider.notifier).markAllRead(),
            child: const Text('Tout marquer lu'),
          ),
      ],
      body: notifs.isEmpty
          ? const Center(
              child: AppEmptyState(
                icon: Icons.notifications_off_outlined,
                title: 'Aucune notification',
                message: 'Vous êtes totalement à jour dans vos cours et vos rappels !',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: notifs.length,
              separatorBuilder: (_, _) => AppSpacing.gapSm,
              itemBuilder: (context, i) {
                final n = notifs[i];
                return Dismissible(
                  key: ValueKey(n.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: context.colors.error,
                      borderRadius: AppRadius.brLg,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  ),
                  onDismissed: (_) => ref.read(notificationsProvider.notifier).remove(n.id),
                  child: AppCard(
                    color: n.read ? null : context.colors.primary.withValues(alpha: 0.05),
                    onTap: () {
                      ref.read(notificationsProvider.notifier).markRead(n.id);
                      if (n.route != null) {
                        Navigator.pop(context);
                      }
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppIconBox(icon: n.category.icon, color: n.category.color, size: 40),
                        AppSpacing.gapSm,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      n.title,
                                      style: context.text.titleSmall?.copyWith(
                                        fontWeight: n.read ? FontWeight.normal : FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (!n.read)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: context.colors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              AppSpacing.gapXxs,
                              Text(n.body, style: context.text.bodyMedium),
                              AppSpacing.gapXxs,
                              Text(
                                Formatters.relative(n.date),
                                style: context.text.labelSmall?.copyWith(color: context.colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
