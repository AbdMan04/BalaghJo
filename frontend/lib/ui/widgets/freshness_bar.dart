// FreshnessBar — "Last updated HH:MM" stamp with a manual refresh action.
// Shown on the admin dashboard tabs so stale data is obvious and can be
// refreshed without a full page reload.
import 'package:flutter/material.dart';
import '../../core/date_format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';

class FreshnessBar extends StatelessWidget {
  final DateTime? lastUpdated;
  final VoidCallback onRefresh;
  const FreshnessBar(
      {super.key, required this.lastUpdated, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final updated = lastUpdated;
    final stamp = updated == null
        ? context.t('admin.last_updated')
        : '${context.t('admin.last_updated')} · ${formatTime(updated)}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          stamp,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        IconButton(
          tooltip: context.t('admin.refresh'),
          onPressed: onRefresh,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.refresh, size: 20, color: AppColors.ink),
        ),
      ],
    );
  }
}
