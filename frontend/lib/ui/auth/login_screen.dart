import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/api_errors.dart';
import '../../core/identifier_validator.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../state/auth_state.dart';
import '../home/main_shell.dart';
import '../widgets/animations.dart';
import '../widgets/password_visibility_toggle.dart';
import 'register_screen.dart';

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
      final identifier = _identifier.text.trim();
      await context.read<AuthState>().login(identifier, _pass.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
          fadeSlideRoute(const MainShell()), (_) => false);
    } catch (e) {
      final msg = cleanErrorMessage(e);
      setState(() => _error = switch (msg) {
        'Incorrect Phone Number!' => context.t('login.phone_not_registered'),
        'Incorrect password' => context.t('login.wrong_password'),
        _ => msg,
      });
      _shake.value++;
    }
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
                        _label(context.t('login.identifier_label'), context.t('ar.phone_number')),
                        // A3: the hint is intentionally small; cap system
                        // text scaling so it doesn't balloon the field.
                        MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.3,
                          child: TextFormField(
                            controller: _identifier,
                            decoration: InputDecoration(
                              hintText: context.t('login.identifier_hint'),
                              hintStyle: const TextStyle(fontSize: 13),
                              prefixIcon: const Icon(Icons.phone_android, color: AppColors.textMuted),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            validator: (v) => validateIdentifier(context, v),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 280),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(context.t('login.password_label'), context.t('ar.password')),
                        TextFormField(
                          controller: _pass,
                          decoration: InputDecoration(
                            hintText: context.t('login.password_hint'),
                            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted),
                            suffixIcon: PasswordVisibilityToggle(
                              obscure: _obscure,
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
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

  Widget _label(String en, String ar) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Row(
          children: [
            Text(en,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.6)),
            const SizedBox(width: 8),
            Text(ar,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          ],
        ),
      );
}
