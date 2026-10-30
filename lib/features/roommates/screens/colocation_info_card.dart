import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/core.dart';
import '../models/roommate_models.dart';

/// Adresse, informations et clé d'invitation du groupe.
class ColocationInfoCard extends StatelessWidget {
  const ColocationInfoCard({super.key, required this.colocation});

  final Colocation colocation;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (colocation.address.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18),
              AppSpacing.gapSm,
              Expanded(child: Text(colocation.address, style: context.text.bodyMedium)),
            ],
          ),
          AppSpacing.gapXs,
        ],
        if (colocation.details.isNotEmpty) ...[
          Text(colocation.details, style: context.text.bodySmall),
          AppSpacing.gapXs,
        ],
        Row(
          children: [
            const Icon(Icons.vpn_key_rounded, size: 18),
            AppSpacing.gapSm,
            Expanded(
              child: Text(
                'Clé d\'invitation : ${colocation.code}',
                style: context.text.labelLarge,
              ),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: colocation.code));
                if (context.mounted) {
                  AppSnackbar.info(context, 'Clé ${colocation.code} copiée !');
                }
              },
              child: const Text('Copier'),
            ),
          ],
        ),
      ],
    ),
  );
}
