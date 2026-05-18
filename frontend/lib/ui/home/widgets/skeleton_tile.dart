// SkeletonTile — placeholder row used while the "Recent Reports"
// list on the home screen is loading. Renders shimmer-style boxes
// matching the real tile's layout so the page doesn't jump when
// data arrives.
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../widgets/animations.dart';

class SkeletonTile extends StatelessWidget {
  const SkeletonTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            SkeletonBox(
              height: 44,
              width: 44,
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 12, width: 160),
                  SizedBox(height: 8),
                  SkeletonBox(height: 10, width: 110),
                  SizedBox(height: 10),
                  SkeletonBox(
                    height: 16,
                    width: 70,
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
