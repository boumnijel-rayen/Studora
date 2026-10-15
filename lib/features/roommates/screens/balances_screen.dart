import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../providers/roommates_providers.dart';

class BalancesScreen extends ConsumerWidget {
  const BalancesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(balancesDueProvider);

    return AppScaffold(
      title: 'Équilibre des soldes',
      subtitle: 'Qui doit combien à qui',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.colors.primary, context.colors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppRadius.brLg,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
                    AppSpacing.gapSm,
                    Expanded(
                      child: Text(
                        'Comptes simplifiés',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapSm,
                Text(
                  'Studora optimise automatiquement les transactions entre colocataires pour réduire le nombre d\'échanges d\'argent.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,

          const AppSectionHeader(title: 'Remboursements suggérés'),
          if (balances.isEmpty)
            const AppCard(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: Text('Tous les comptes sont équilibrés ! 🤝')),
            )
          else
            for (final b in balances) ...[
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppAvatar(name: b.fromPerson, size: 40),
                    AppSpacing.gapSm,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Titre « A → B » : revient à la ligne si les noms sont longs.
                          Text.rich(
                            TextSpan(
                              style: context.text.titleSmall,
                              children: [
                                TextSpan(text: b.fromPerson),
                                const WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(Icons.arrow_forward_rounded, size: 14),
                                  ),
                                ),
                                TextSpan(text: b.toPerson),
                              ],
                            ),
                            softWrap: true,
                          ),
                          AppSpacing.gapXxs,
                          Text('Remboursement direct suggéré', style: context.text.bodySmall),
                        ],
                      ),
                    ),
                    AppSpacing.gapSm,
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              Formatters.money(b.amount),
                              style: context.text.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: context.colors.primary,
                              ),
                            ),
                          ),
                          AppSpacing.gapXs,
                          AppButton(
                            label: 'Régler',
                            size: AppButtonSize.sm,
                            variant: AppButtonVariant.tonal,
                            onPressed: () {
                              AppSnackbar.success(
                                context,
                                'Remboursement de ${Formatters.money(b.amount)} validé !',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.gapSm,
            ],
        ],
      ),
    );
  }
}
