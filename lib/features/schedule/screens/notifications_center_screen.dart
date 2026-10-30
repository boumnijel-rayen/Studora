import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';

class NotificationsCenterScreen extends ConsumerWidget {
  const NotificationsCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsAsyncProvider);
    final notifs = notifsAsync.asData?.value ?? const <AppNotification>[];

    return AppScaffold(
      title: 'Notifications',
      subtitle: '${notifs.where((n) => !n.read).length} non lues',
      actions: [
        if (notifs.isNotEmpty)
          TextButton(
            onPressed: () async {
              try {
                await ref.read(notificationsAsyncProvider.notifier).markAllRead();
              } catch (e) {
                if (context.mounted) {
                  AppSnackbar.error(context, ApiException.fromError(e).message);
                }
              }
            },
            child: const Text('Tout marquer lu'),
          ),
      ],
      body: AppAsyncView<List<AppNotification>>(
        value: notifsAsync,
        isEmpty: (list) => list.isEmpty,
        empty: const AppEmptyState(
          icon: Icons.notifications_off_outlined,
          title: 'Aucune notification',
          message: 'Vous êtes totalement à jour dans vos cours et vos rappels !',
        ),
        onRetry: () => ref.invalidate(notificationsAsyncProvider),
        data: (list) => ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: list.length,
          separatorBuilder: (_, _) => AppSpacing.gapSm,
          itemBuilder: (context, i) {
            final n = list[i];
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
              onDismissed: (_) {
                ref.read(notificationsAsyncProvider.notifier).remove(n.id);
              },
              child: AppCard(
                color: n.read ? null : context.colors.primary.withValues(alpha: 0.05),
                onTap: () {
                  ref.read(notificationsAsyncProvider.notifier).markRead(n.id);
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
      ),
    );
  }
}
