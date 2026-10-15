import 'package:flutter/material.dart';

import '../../core/core.dart';

/// Galerie de test et vitrine de l'ensemble des composants du Design System.
class DesignSystemGalleryScreen extends StatefulWidget {
  const DesignSystemGalleryScreen({super.key});

  @override
  State<DesignSystemGalleryScreen> createState() => _DesignSystemGalleryScreenState();
}

class _DesignSystemGalleryScreenState extends State<DesignSystemGalleryScreen> {
  final _textCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _segmentedVal = 'Jour';
  String _filterVal = 'Tous';
  bool _switchVal = true;
  double _progressVal = 0.65;
  String? _dropdownVal;

  @override
  void dispose() {
    _textCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Design System Studora',
    subtitle: 'Composants, Tokens & États visuels',
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Section 1 : Palette de couleurs
        const AppSectionHeader(title: 'Palette de Couleurs'),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            _colorChip('Primary', context.colors.primary),
            _colorChip('Secondary', context.colors.secondary),
            _colorChip('Tertiary', context.colors.tertiary),
            _colorChip('Success', context.colors.success),
            _colorChip('Warning', context.colors.warning),
            _colorChip('Error', context.colors.error),
            _colorChip('Info', context.colors.info),
          ],
        ),
        AppSpacing.gapLg,

        // Section 2 : Boutons et Variantes
        const AppSectionHeader(title: 'Boutons'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppButton(label: 'Principal', icon: Icons.star_rounded, onPressed: () {}),
            AppButton(label: 'Secondaire', variant: AppButtonVariant.secondary, onPressed: () {}),
            AppButton(label: 'Tonal', variant: AppButtonVariant.tonal, onPressed: () {}),
            AppButton(label: 'Ghost', variant: AppButtonVariant.ghost, onPressed: () {}),
            AppButton(label: 'Danger', variant: AppButtonVariant.danger, onPressed: () {}),
            AppButton(label: 'Chargement', isLoading: true, onPressed: () {}),
            AppIconButton(icon: Icons.notifications_rounded, badgeCount: 3, onPressed: () {}),
          ],
        ),
        AppSpacing.gapLg,

        // Section 3 : Formulaires et Saisies
        const AppSectionHeader(title: 'Champs de Saisie'),
        AppCard(
          child: Column(
            children: [
              AppTextField(
                controller: _textCtrl,
                label: 'Nom complet',
                hint: 'ex: Rayen Ben Ali',
                prefixIcon: Icons.badge_outlined,
              ),
              AppSpacing.gapMd,
              const AppPasswordField(label: 'Mot de passe sécurisé'),
              AppSpacing.gapMd,
              AppSearchField(controller: _searchCtrl, hint: 'Rechercher un cours...'),
              AppSpacing.gapMd,
              AppDropdownField<String>(
                label: 'Semestre académique',
                value: _dropdownVal,
                hint: 'Sélectionner le semestre',
                items: const ['Semestre 1', 'Semestre 2', 'Semestre 3', 'Semestre 4'],
                itemLabel: (s) => s,
                onChanged: (v) => setState(() => _dropdownVal = v),
              ),
              AppSpacing.gapMd,
              AppDateField(label: 'Date de l\'examen', initialValue: DateTime.now()),
              AppSpacing.gapMd,
              AppTimeField(label: 'Heure de début', initialValue: const TimeOfDay(hour: 8, minute: 30)),
            ],
          ),
        ),
        AppSpacing.gapLg,

        // Section 4 : Badges, Avatars et Puces
        const AppSectionHeader(title: 'Indicateurs, Puces & Avatars'),
        const Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            AppBadge(label: 'Validé', tone: AppBadgeTone.success, icon: Icons.check_circle_rounded),
            AppBadge(label: 'En attente', tone: AppBadgeTone.warning, icon: Icons.hourglass_empty_rounded),
            AppBadge(label: 'Urgent', tone: AppBadgeTone.error, icon: Icons.error_outline_rounded),
            AppBadge(label: 'Information', tone: AppBadgeTone.info),
          ],
        ),
        AppSpacing.gapMd,
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (var i = 0; i < MockSharedData.subjects.length; i++)
              SubjectChip(
                label: MockSharedData.subjects[i].shortName,
                color: MockSharedData.subjects[i].color,
              ),
          ],
        ),
        AppSpacing.gapMd,
        const Row(
          children: [
            AppAvatar(name: 'Rayen Ben Ali', size: 48, showOnline: true),
            AppSpacing.gapSm,
            AppAvatar(name: 'Alice Dubois', size: 48),
            AppSpacing.gapSm,
            AppAvatarStack(names: ['Rayen', 'Alice', 'Marc', 'Inès', 'Thomas', 'Sophie']),
          ],
        ),
        AppSpacing.gapLg,

        // Section 5 : Progression et Anneaux
        const AppSectionHeader(title: 'Indicateurs de Progression'),
        Row(
          children: [
            AppProgressRing(
              value: _progressVal,
              size: 80,
              strokeWidth: 8,
              color: AppColors.primary,
              child: Text('${(_progressVal * 20).toStringAsFixed(1)}/20', style: context.text.titleSmall),
            ),
            AppSpacing.gapLg,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Progression du semestre', style: context.text.labelMedium),
                  AppSpacing.gapXs,
                  AppProgressBar(value: _progressVal, color: AppColors.tertiary),
                  AppSpacing.gapXs,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _progressVal = (_progressVal + 0.1) % 1.0),
                        child: const Text('Incrémenter +10%'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        AppSpacing.gapLg,

        // Section 6 : Contrôles & Interrupteurs
        const AppSectionHeader(title: 'Sélection & Filtres'),
        AppSegmentedControl<String>(
          segments: const {'Jour': 'Jour', 'Semaine': 'Semaine', 'Mois': 'Mois'},
          selected: _segmentedVal,
          onChanged: (v) => setState(() => _segmentedVal = v),
        ),
        AppSpacing.gapMd,
        AppFilterChips<String>(
          padding: EdgeInsets.zero,
          options: const {
            'Tous': 'Tous',
            'Maths': 'Mathématiques',
            'Algo': 'Algorithmique',
            'Mobile': 'Mobile',
          },
          selected: _filterVal,
          onSelected: (v) => setState(() => _filterVal = v),
        ),
        AppSpacing.gapMd,
        AppSwitchTile(
          title: 'Notifications en temps réel',
          subtitle: 'Rappels 30 min avant le début des cours',
          value: _switchVal,
          onChanged: (v) => setState(() => _switchVal = v),
        ),
        AppSpacing.gapLg,

        // Section 7 : Dialogues, Feuilles & Snackbars
        const AppSectionHeader(title: 'Overlays & Alertes'),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            AppButton(
              label: 'Modal BottomSheet',
              variant: AppButtonVariant.tonal,
              onPressed: () {
                AppBottomSheet.show(
                  context,
                  title: 'Détail de l\'élément',
                  child: Column(
                    children: [
                      const Text('Ceci est une feuille modale réutilisable conforme au Design System.'),
                      AppSpacing.gapMd,
                      AppButton(
                        label: 'Fermer',
                        expand: true,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                );
              },
            ),
            AppButton(
              label: 'Dialogue Confirmation',
              variant: AppButtonVariant.tonal,
              onPressed: () async {
                final res = await AppConfirmDialog.show(
                  context,
                  title: 'Confirmer l\'action ?',
                  message: 'Cette action démontre la boîte de confirmation standard.',
                );
                if (context.mounted && res) {
                  AppSnackbar.success(context, 'Action confirmée avec succès !');
                }
              },
            ),
            AppButton(
              label: 'Notification Toast',
              variant: AppButtonVariant.ghost,
              onPressed: () => AppSnackbar.info(context, 'Exemple de notification éphémère Studora'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _colorChip(String name, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
    decoration: BoxDecoration(color: c, borderRadius: AppRadius.brMd),
    child: Text(
      name,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
    ),
  );
}
