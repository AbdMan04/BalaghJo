// Filter-chip widgets used at the top of the My Reports and Reports
// Map screens. StatusFilterChip is a solid pill (ink when active,
// white otherwise). CategoryFilterChip is a tinted outlined pill with
// an optional leading category icon.
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../widgets/animations.dart';
import '../../widgets/category_icon.dart';

class StatusFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const StatusFilterChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.navy : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? AppColors.navy : AppColors.border),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 240),
            style: TextStyle(
              color: active ? Colors.white : AppColors.navy,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class CategoryFilterChip extends StatelessWidget {
  final String label;
  final String? value; // null means "All categories"
  final bool active;
  final VoidCallback onTap;
  const CategoryFilterChip({
    super.key,
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = value == null ? AppColors.blue : colorForCategory(value!);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? tint.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? tint : AppColors.border,
              width: active ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null) ...[
                Icon(iconForCategory(value!), size: 13, color: active ? tint : AppColors.textMuted),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: active ? tint : AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
