import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../providers/groups_providers.dart';

class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      AppSnackbar.error(context, 'Veuillez saisir un code de groupe');
      return;
    }

    setState(() => _isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    ref.read(groupsProvider.notifier).joinGroup(code);
    AppSnackbar.success(context, 'Vous avez rejoint le groupe d\'étude avec succès !');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Rejoindre un groupe',
    body: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.1),
              borderRadius: AppRadius.brLg,
            ),
            child: Row(
              children: [
                const Icon(Icons.qr_code_2_rounded, size: 40, color: AppColors.primary),
                AppSpacing.gapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Code d\'invitation', style: context.text.titleSmall),
                      Text(
                        'Demandez le code à 6 caractères à l\'un des membres du groupe.',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapXl,

          AppTextField(
            controller: _codeCtrl,
            label: 'Code du groupe',
            hint: 'ex: ALGO42 ou MATH99',
            prefixIcon: Icons.key_rounded,
          ),
          AppSpacing.gapLg,

          AppButton(
            label: 'Rejoindre le groupe',
            icon: Icons.check_circle_outline_rounded,
            isLoading: _isLoading,
            expand: true,
            onPressed: _join,
          ),
        ],
      ),
    ),
  );
}
