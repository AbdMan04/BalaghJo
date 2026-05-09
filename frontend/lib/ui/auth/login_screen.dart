import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/identifier_validator.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../state/auth_state.dart';
import '../home/main_shell.dart';
import '../widgets/animations.dart';
import 'register_screen.dart';
import 'verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _pass = TextEditingController();
  final _shake = ValueNotifier<int>(0);
  bool _obscure = true;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) {
      _shake.value++;
      return;
    }
    setState(() => _error = null);
    try {
      final raw = _identifier.text.trim();
      final identifier = raw.contains('@') ? raw.toLowerCase() : raw;
      await context.read<AuthState>().login(identifier, _pass.text);
      if (!mounted) return;
      final user = context.read<AuthState>().user;
      final next = (user?.isVerified == false)
          ? const VerificationScreen()
          : const MainShell();
      Navigator.of(context).pushAndRemoveUntil(
          fadeSlideRoute(next), (_) => false);
    } catch (e) {
      setState(() => _error = _cleanError(e));
      _shake.value++;
    }
  }

  String _cleanError(Object e) {
    final s = e.toString();
    return s.replaceFirst(RegExp(r'^(Exception|ApiException\([^)]*\)):\s*'), '');
  }

  @override
  void dispose() {
    _identifier.dispose();
    _pass.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthState>().loading;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ShakeWidget(
          trigger: _shake,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeSlideIn(
                    child: Row(
                      children: [
                        Hero(
                          tag: 'app-logo',
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.navy,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: const Icon(Icons.location_on, color: Colors.white, size: 22),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BALAGHJO',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 2)),
                            Text('Civic Reporting Platform',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 80),
                    child: Text(context.t('login.welcome_back'),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 4),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 140),
                    child: Text(context.t('login.subtitle'),
                        style: const TextStyle(color: AppColors.textMuted)),
                  ),
                  const SizedBox(height: 28),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(context.t('login.identifier_label')),
                        TextFormField(
                          controller: _identifier,
                          decoration: InputDecoration(
                            hintText: context.t('login.identifier_hint'),
                            prefixIcon: const Icon(Icons.person_outline, color: AppColors.textMuted),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => validateIdentifier(context, v),
                        ),
                      ],
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 280),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(context.t('login.password_label')),
                        TextFormField(
                          controller: _pass,
                          decoration: InputDecoration(
                            hintText: context.t('login.password_hint'),
                            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: AppColors.textMuted),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          obscureText: _obscure,
                          validator: (v) => (v == null || v.isEmpty) ? context.t('common.required') : null,
                        ),
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _error == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(_error!,
                                          style: const TextStyle(color: AppColors.danger, fontSize: 12))),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 360),
                    child: PressableScale(
                      onTap: loading ? null : _submit,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.navy.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: loading
                              ? const SizedBox(
                                  key: ValueKey('l'),
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  context.t('login.sign_in'),
                                  key: const ValueKey('t'),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pushReplacement(
                          fadeSlideRoute(const RegisterScreen())),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: context.t('login.no_account'), style: const TextStyle(color: AppColors.textMuted)),
                        TextSpan(text: context.t('login.sign_up_link'), style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w700)),
                      ])),
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

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.6)),
      );
}
