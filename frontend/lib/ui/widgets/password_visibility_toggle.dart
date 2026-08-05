// Shared show/hide password toggle used by every password field (login,
// register, profile change-password). Single source of truth for the icon,
// sizing, and localized tooltip.
import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';

class PasswordVisibilityToggle extends StatelessWidget {
  final bool obscure;
  final VoidCallback onPressed;
  final double size;

  const PasswordVisibilityToggle({
    super.key,
    required this.obscure,
    required this.onPressed,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: size,
        color: AppColors.textMuted,
      ),
      tooltip: context.t('common.toggle_password'),
      onPressed: onPressed,
    );
  }
}
