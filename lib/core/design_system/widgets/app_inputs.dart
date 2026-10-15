import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_palette.dart';
import '../tokens/app_dimensions.dart';

/// Champ texte standard avec label au-dessus.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.initialValue,
    this.autofillHints,
    this.maxLength,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? initialValue;
  final Iterable<String>? autofillHints;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      initialValue: initialValue,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      autofillHints: autofillHints,
      maxLength: maxLength,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: context.text.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: AppSizes.iconMd),
        suffixIcon: suffix,
      ),
    );
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label!, style: context.text.labelMedium),
        AppSpacing.gapXs,
        field,
      ],
    );
  }
}

/// Champ mot de passe avec bouton afficher/masquer.
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    this.controller,
    this.label = 'Mot de passe',
    this.hint = '••••••••',
    this.validator,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => AppTextField(
    controller: widget.controller,
    label: widget.label,
    hint: widget.hint,
    prefixIcon: Icons.lock_outline_rounded,
    obscureText: _hidden,
    validator: widget.validator,
    textInputAction: widget.textInputAction,
    onSubmitted: widget.onSubmitted,
    autofillHints: const [AutofillHints.password],
    suffix: IconButton(
      tooltip: _hidden ? 'Afficher' : 'Masquer',
      icon: Icon(
        _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: AppSizes.iconMd,
      ),
      onPressed: () => setState(() => _hidden = !_hidden),
    ),
  );
}

/// Barre de recherche arrondie.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.hint = 'Rechercher…',
    this.onChanged,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    style: context.text.bodyMedium,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search_rounded, size: AppSizes.iconMd),
      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      border: const OutlineInputBorder(
        borderRadius: AppRadius.brFull,
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.brFull,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.brFull,
        borderSide: BorderSide(color: context.colors.primary, width: 1.4),
      ),
    ),
  );
}

/// Liste déroulante typée.
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.value,
    this.label,
    this.hint,
    this.prefixIcon,
    this.validator,
  });

  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;
  final T? value;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final FormFieldValidator<T>? validator;

  @override
  Widget build(BuildContext context) {
    final field = DropdownButtonFormField<T>(
      value: value,
      validator: validator,
      onChanged: onChanged,
      isExpanded: true,
      borderRadius: AppRadius.brMd,
      dropdownColor: context.colors.surface,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      style: context.text.bodyLarge,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: AppSizes.iconMd),
      ),
      items: [
        for (final i in items)
          DropdownMenuItem<T>(value: i, child: Text(itemLabel(i))),
      ],
    );
    return _Labeled(label: label, child: field);
  }
}

/// Champ de sélection de date (ouvre le DatePicker).
class AppDateField extends FormField<DateTime> {
  AppDateField({
    super.key,
    super.initialValue,
    super.validator,
    String? label,
    String hint = 'Choisir une date',
    DateTime? firstDate,
    DateTime? lastDate,
    ValueChanged<DateTime>? onChanged,
  }) : super(
         autovalidateMode: AutovalidateMode.onUserInteraction,
         builder: (state) {
           final ctx = state.context;
           return _Labeled(
             label: label,
             child: _PickerBox(
               icon: Icons.calendar_today_rounded,
               text: state.value == null
                   ? hint
                   : DateFormat('EEEE d MMMM y', 'fr_FR').format(state.value!),
               isPlaceholder: state.value == null,
               errorText: state.errorText,
               onTap: () async {
                 final now = DateTime.now();
                 final picked = await showDatePicker(
                   context: ctx,
                   initialDate: state.value ?? now,
                   firstDate: firstDate ?? DateTime(now.year - 2),
                   lastDate: lastDate ?? DateTime(now.year + 3),
                   locale: const Locale('fr', 'FR'),
                 );
                 if (picked != null) {
                   state.didChange(picked);
                   onChanged?.call(picked);
                 }
               },
             ),
           );
         },
       );
}

/// Champ de sélection d'heure (ouvre le TimePicker).
class AppTimeField extends FormField<TimeOfDay> {
  AppTimeField({
    super.key,
    super.initialValue,
    super.validator,
    String? label,
    String hint = 'Choisir une heure',
    ValueChanged<TimeOfDay>? onChanged,
  }) : super(
         autovalidateMode: AutovalidateMode.onUserInteraction,
         builder: (state) {
           final ctx = state.context;
           String fmt(TimeOfDay t) =>
               '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
           return _Labeled(
             label: label,
             child: _PickerBox(
               icon: Icons.schedule_rounded,
               text: state.value == null ? hint : fmt(state.value!),
               isPlaceholder: state.value == null,
               errorText: state.errorText,
               onTap: () async {
                 final picked = await showTimePicker(
                   context: ctx,
                   initialTime: state.value ?? TimeOfDay.now(),
                   builder: (c, child) => MediaQuery(
                     data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
                     child: child!,
                   ),
                 );
                 if (picked != null) {
                   state.didChange(picked);
                   onChanged?.call(picked);
                 }
               },
             ),
           );
         },
       );
}

/// Ligne avec interrupteur (préférences).
class AppSwitchTile extends StatelessWidget {
  const AppSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    value: value,
    onChanged: onChanged,
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    secondary: icon == null ? null : Icon(icon, color: context.colors.textSecondary),
    title: Text(title, style: context.text.bodyLarge),
    subtitle: subtitle == null ? null : Text(subtitle!, style: context.text.bodySmall),
  );
}

/// Sélecteur segmenté (Jour / Semaine, filtres exclusifs…).
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  /// valeur → libellé
  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: AppRadius.brMd),
      child: Row(
        children: [
          for (final e in segments.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(e.key),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: AppDurations.normal,
                  curve: AppDurations.curve,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
                  decoration: BoxDecoration(
                    color: e.key == selected ? c.surface : Colors.transparent,
                    borderRadius: AppRadius.brSm,
                    boxShadow: e.key == selected ? AppShadows.soft(context.brightness) : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    e.value,
                    style: context.text.labelMedium?.copyWith(
                      color: e.key == selected ? c.primary : c.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Privés ────────────────────────────────────────────────────

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});
  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (label == null) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label!, style: context.text.labelMedium),
        AppSpacing.gapXs,
        child,
      ],
    );
  }
}

class _PickerBox extends StatelessWidget {
  const _PickerBox({
    required this.icon,
    required this.text,
    required this.isPlaceholder,
    required this.onTap,
    this.errorText,
  });

  final IconData icon;
  final String text;
  final bool isPlaceholder;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: c.surfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.brMd,
            side: errorText != null ? BorderSide(color: c.error) : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: AppSizes.input,
              child: Row(
                children: [
                  AppSpacing.gapSm,
                  Icon(icon, size: AppSizes.iconMd, color: c.textSecondary),
                  AppSpacing.gapSm,
                  Expanded(
                    child: Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyLarge?.copyWith(
                        color: isPlaceholder ? c.textSecondary : c.textPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: c.textSecondary),
                  AppSpacing.gapSm,
                ],
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm, top: AppSpacing.xxs),
            child: Text(errorText!, style: context.text.labelSmall?.copyWith(color: c.error)),
          ),
      ],
    );
  }
}
