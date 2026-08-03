// ReportThumbnail — shared widget that renders a report's photo as a
// square thumbnail, falling back to the category icon when the photo
// is missing, still loading, or fails to fetch. Uses the disk-backed
// cache and decodes at display size so list rebuilds don't re-download
// or full-size-decode every image.
import 'package:cached_network_image/cached_network_image.dart';
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
          : CachedNetworkImage(
              imageUrl: AppConfig.imageUrl(report.photoUrl),
              fit: BoxFit.cover,
              memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
              placeholder: (_, __) => _fallback(),
              errorWidget: (_, __, ___) => _fallback(),
            ),
    );
  }
}
