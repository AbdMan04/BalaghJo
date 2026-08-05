// ProfileScreen — feature F1 (User Authentication, FR-3 view and edit
// profile information).
// Shows the authenticated user's name, contact info.
//Provides edit-profile, change password and log-out actions.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/api_errors.dart';
import '../../core/identifier_validator.dart';
import '../../core/locale_state.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models/user.dart';
import '../../state/auth_state.dart';
import '../auth/onboarding_screen.dart';
import '../notifications/notifications_screen.dart';
import '../widgets/animations.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _CoverHeader(user: user, onEdit: () => _showEditProfile(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 260),
                    child: _row(
                        Icons.lock_outline,
                        context.t('profile.change_password'),
                        () => _showChangePassword(context)),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 320),
                    child: _row(
                      Icons.notifications_none,
                      context.t('profile.notifications'),
                      () => Navigator.of(context).push(
                          fadeSlideRoute(const NotificationsScreen())),
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 380),
                    child: _row(
                        Icons.language_outlined,
                        context.t('profile.language'),
                        () => _showLanguage(context)),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 440),
                    child: _row(
                      Icons.logout,
                      context.t('profile.log_out'),
                      () async {
                        final confirmed = await _confirmLogout(context);
                        if (!confirmed || !context.mounted) return;
                        await context.read<AuthState>().logout();
                        if (!context.mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                            fadeSlideRoute(const OnboardingScreen()),
                            (_) => false);
                      },
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePassword(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
  }

  void _showEditProfile(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: const _EditProfileSheet(),
      ),
    );
  }

  void _showLanguage(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(context.t('profile.language_title'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.translate, color: AppColors.blue),
              title: Text(context.t('profile.language_en')),
              trailing: context.watch<LocaleState>().isArabic
                  ? null
                  : const Icon(Icons.check_circle,
                      color: AppColors.success, size: 20),
              onTap: () {
                context.read<LocaleState>().setLocale(const Locale('en'));
                Navigator.pop(sheetCtx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.translate, color: AppColors.blue),
              title: Text(context.t('profile.language_ar'),
                  style: const TextStyle(color: AppColors.navy)),
              trailing: context.watch<LocaleState>().isArabic
                  ? const Icon(Icons.check_circle,
                      color: AppColors.success, size: 20)
                  : null,
              onTap: () {
                context.read<LocaleState>().setLocale(const Locale('ar'));
                Navigator.pop(sheetCtx);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmLogout(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('profile.logout_title')),
        content: Text(context.t('profile.logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              context.t('profile.log_out'),
              style: const TextStyle(
                  color: AppColors.danger, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _row(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (color ?? AppColors.navy).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: color ?? AppColors.navy, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: color)),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _hideCurrent = true;
  bool _hideNext = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_current.text.isEmpty) {
      setState(() => _error = context.t('profile.err_current_required'));
      return;
    }
    if (_next.text.length < 6) {
      setState(() => _error = context.t('profile.err_new_short'));
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = context.t('profile.err_mismatch'));
      return;
    }
    if (_current.text == _next.text) {
      setState(() => _error = context.t('profile.err_same'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(context.t('profile.password_updated')),
          ]),
        ),
      );
    } catch (e) {
      setState(() {
        _busy = false;
        _error = cleanErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
      title: Text(context.t('profile.change_password'),
          style: const TextStyle(fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _current,
              obscureText: _hideCurrent,
              decoration: InputDecoration(
                labelText: context.t('profile.current_password'),
                suffixIcon: IconButton(
                  icon: Icon(
                      _hideCurrent
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: AppColors.textMuted),
                  onPressed: () => setState(() => _hideCurrent = !_hideCurrent),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _next,
              obscureText: _hideNext,
              decoration: InputDecoration(
                labelText: context.t('profile.new_password'),
                suffixIcon: IconButton(
                  icon: Icon(
                      _hideNext
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: AppColors.textMuted),
                  onPressed: () => setState(() => _hideNext = !_hideNext),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirm,
              obscureText: _hideNext,
              decoration:
                  InputDecoration(labelText: context.t('profile.confirm_new')),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.danger, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.danger, fontSize: 12))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(context.t('common.cancel')),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.calmBlue,
            foregroundColor: Colors.white,
          ),
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(context.t('common.update')),
        ),
      ],
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet();

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _phone;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthState>().user;
    _first = TextEditingController(text: user?.firstName ?? '');
    _last = TextEditingController(text: user?.lastName ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      setState(() => _error = context.t('profile.err_names_required'));
      return;
    }
    final phone = _phone.text.trim();
    if (phone.isNotEmpty && !joPhoneRegex.hasMatch(phone)) {
      setState(() => _error = context.t('login.invalid_phone'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().updateProfile(
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            phone: _phone.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(context.t('profile.profile_updated')),
          ]),
        ),
      );
    } catch (e) {
      setState(() {
        _busy = false;
        _error = cleanErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(context.t('profile.edit_profile'),
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 4),
            Text(context.t('profile.edit_subtitle'),
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _first,
                    decoration: InputDecoration(
                      labelText: context.t('profile.first_name'),
                      prefixIcon: const Icon(Icons.person_outline,
                          color: AppColors.textMuted),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _last,
                    decoration: InputDecoration(
                        labelText: context.t('profile.last_name')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                labelText: context.t('profile.phone'),
                prefixIcon: const Icon(Icons.phone_outlined,
                    color: AppColors.textMuted),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.danger, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.danger, fontSize: 12))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            PressableScale(
              onTap: _busy ? null : _save,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.blue.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _busy
                      ? const SizedBox(
                          key: ValueKey('l'),
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          context.t('profile.save_changes'),
                          key: const ValueKey('t'),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverHeader extends StatelessWidget {
  final AppUser? user;
  final VoidCallback onEdit;
  const _CoverHeader({required this.user, required this.onEdit});

  String get _initials {
    final first = (user?.firstName ?? '').trim();
    final last = (user?.lastName ?? '').trim();
    final f = first.isNotEmpty ? first[0] : '';
    final l = last.isNotEmpty ? last[0] : '';
    final s = (f + l).toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  @override
  Widget build(BuildContext context) {
    final fullName = (user?.fullName ?? '').trim();
    final contact = user?.phone ?? '';
    return Column(
      children: [
        SizedBox(
          height: 260,
          child: Stack(
            children: [
              Container(
                height: 200,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.navy,
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
              ),
              Positioned(
                top: 50,
                left: 20,
                right: 20,
                child: Text(
                  context.t('profile.title'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Center(
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.blue.withValues(alpha: 0.35),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 46,
                              backgroundColor: AppColors.navy,
                              child: Text(
                                _initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 28,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: PressableScale(
                            onTap: onEdit,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.blue,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black38, blurRadius: 8)
                                ],
                              ),
                              child: const Icon(Icons.edit,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          fullName.isNotEmpty ? fullName : '—',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        const SizedBox(height: 4),
        Text(
          contact,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}
