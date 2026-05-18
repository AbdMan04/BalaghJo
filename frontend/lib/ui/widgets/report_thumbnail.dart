// ReportThumbnail — shared widget that renders a report's photo as a
// square thumbnail, falling back to the category icon when the photo
// is missing, still loading, or fails to fetch. Used by the home
// Recent Reports tile and the My Reports list row.
import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../data/models/report.dart';
import 'category_icon.dart';

class ReportThumbnail extends StatelessWidget {
  final Report report;
  final double size;
  const ReportThumbnail({super.key, required this.report, this.size = 44});

  Widget _fallback() => Container(
        color: colorForCategory(report.category).withValues(alpha: 0.12),
        alignment: Alignment.center,
        child: Icon(
          iconForCategory(report.category),
          color: colorForCategory(report.category),
          size: 22,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: report.photoUrl.isEmpty
          ? _fallback()
          : Image.network(
              '${AppConfig.apiBaseUrl}${report.photoUrl}',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : _fallback(),
            ),
    );
  }
}
