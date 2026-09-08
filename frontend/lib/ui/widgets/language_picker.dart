// Shared language picker used by the profile and authentication screens.
// [LanguagePickerButton] renders the current language as a compact rounded
// rectangle and opens [showLanguagePicker]: a transparent dialog floating in
// the middle of the screen with the two supported languages, the active one
// marked with a plain blue check. Screens pass already-localized strings
// (title/enLabel/arLabel) so each one controls its own AppStrings keys while
// sharing the same layout and behaviour.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/locale_state.dart';
import '../../core/theme.dart';

/// Opens the centered, transparent language picker dialog.
/// [title], [enLabel] and [arLabel] are already-localized strings.
void showLanguagePicker(
  BuildContext context, {
  required String title,
  required String enLabel,
  required String arLabel,
}) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black45,
    builder: (_) => _LanguagePickerDialog(
      title: title,
      enLabel: enLabel,
      arLabel: arLabel,
    ),
  );
}

/// A compact rounded rectangle that always shows the current language
/// (e.g. "English" or "العربية"). Tapping it opens [showLanguagePicker].
class LanguagePickerButton extends StatelessWidget {
  final String title;
  final String enLabel;
  final String arLabel;
  const LanguagePickerButton({
    super.key,
    required this.title,
    required this.enLabel,
    required this.arLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<LocaleState>().isArabic;
    return OutlinedButton(
      key: const ValueKey('language-picker-button'),
      onPressed: () => showLanguagePicker(
        context,
        title: title,
        enLabel: enLabel,
        arLabel: arLabel,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      child: Text(isArabic ? arLabel : enLabel),
    );
  }
}

/// The transparent centered dialog listing both languages; the active one
/// carries a plain blue check with no background box around it.
class _LanguagePickerDialog extends StatelessWidget {
  final String title;
  final String enLabel;
  final String arLabel;
  const _LanguagePickerDialog({
    required this.title,
    required this.enLabel,
    required this.arLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<LocaleState>().isArabic;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Material(
          color: Colors.white.withValues(alpha: 0.94),
          elevation: 24,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                _LanguageOption(
                  label: enLabel,
                  selected: !isArabic,
                  onTap: () {
                    context.read<LocaleState>().setLocale(const Locale('en'));
                    Navigator.pop(context);
                  },
                ),
                _LanguageOption(
                  label: arLabel,
                  selected: isArabic,
                  onTap: () {
                    context.read<LocaleState>().setLocale(const Locale('ar'));
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            if (selected)
              const Icon(Icons.check, color: AppColors.blue, size: 20),
          ],
        ),
      ),
    );
  }
}
