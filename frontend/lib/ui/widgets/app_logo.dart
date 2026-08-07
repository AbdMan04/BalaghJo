// AppLogoMark — the road-sign tile: safety yellow with an asphalt pin.
// Used on the splash and the login header, wrapped in a Hero(tag: 'app-logo')
// so the mark flies between the two.
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class AppLogoMark extends StatelessWidget {
  final double size;
  final double iconSize;
  const AppLogoMark({
    super.key,
    this.size = 56,
    this.iconSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(size * 0.18),
      decoration: BoxDecoration(
        color: AppColors.safety,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(Icons.location_on, color: AppColors.ink, size: iconSize),
    );
  }
}
