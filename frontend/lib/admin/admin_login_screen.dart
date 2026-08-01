import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_errors.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../state/auth_state.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final phone = _phone.text.trim();
    if (phone.length != 10) {
      setState(() => _error = context.t('login.invalid_phone'));
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = context.t('login.enter_phone'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().login(phone, _password.text);
      if (!mounted) return;
      final user = context.read<AuthState>().user;
      if (user != null && !user.isAdmin) {
        await context.read<AuthState>().logout();
        if (!mounted) return;
        setState(() => _error = 'This account does not have admin access');
        return;
      }
    } catch (e) {
      if (mounted) setState(() => _error = cleanErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.admin_panel_settings_outlined,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 16),
                  const Text('BALAGHJO Admin',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                  const SizedBox(height: 4),
                  const Text('Sign in with an admin account',
                      style: TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: context.t('login.identifier_label'),
                      hintText: context.t('login.identifier_hint'),
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: _hide,
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: context.t('login.password_label'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_hide
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
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
                                    color: AppColors.danger, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _login,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(context.t('login.sign_in')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
