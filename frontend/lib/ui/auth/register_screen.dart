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
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
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
      await context.read<AuthState>().register(
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            password: _pass.text,
            phone: _phone.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context)
          .pushAndRemoveUntil(fadeSlideRoute(const MainShell()), (_) => false);
    } catch (e) {
      setState(() => _error = cleanErrorMessage(e));
      _shake.value++;
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _first.dispose();
    _last.dispose();
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
                    child: Text(context.t('register.create_account'),
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 4),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 80),
                    child: Text(context.t('register.subtitle'),
                        style: const TextStyle(color: AppColors.textMuted)),
                  ),
                  const SizedBox(height: 24),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 140),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(context.t('register.phone_label'),
                            context.t('ar.phone_number')),
                        // A3: cap text scaling on the small hint.
                        MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.3,
                          child: TextFormField(
                            controller: _phone,
                            decoration: InputDecoration(
                              hintText: context.t('register.phone_hint'),
                              hintStyle: const TextStyle(fontSize: 13),
                              prefixIcon: const Icon(Icons.phone_android,
                                  color: AppColors.textMuted),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            validator: (v) => (v == null || !joPhoneRegex.hasMatch(v.trim()))
                                ? context.t('login.invalid_phone')
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 260),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label(context.t('register.first_name'),
                                  context.t('ar.first_name')),
                              TextFormField(
                                controller: _first,
                                decoration: InputDecoration(
                                    hintText: context.t('register.first_hint')),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? context.t('common.required')
                                        : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label(context.t('register.last_name'),
                                  context.t('ar.last_name')),
                              TextFormField(
                                controller: _last,
                                decoration: InputDecoration(
                                    hintText: context.t('register.last_hint')),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? context.t('common.required')
                                        : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 320),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(context.t('register.password'),
                            context.t('ar.password')),
                        TextFormField(
                          controller: _pass,
                          decoration: InputDecoration(
                            hintText: context.t('register.password_hint'),
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: AppColors.textMuted),
                            suffixIcon: PasswordVisibilityToggle(
                              obscure: _obscure,
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          obscureText: _obscure,
                          validator: (v) => (v == null || v.length < 6)
                              ? context.t('register.password_min')
                              : null,
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
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                                border: Border.all(
                                    color: AppColors.danger
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: AppColors.danger, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(_error!,
                                          style: const TextStyle(
                                              color: AppColors.danger,
                                              fontSize: 12))),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 400),
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
                              color: AppColors.navy.withValues(alpha: 0.35),
                              blurRadius: 18,
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
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  context.t('register.sign_up'),
                                  key: const ValueKey('t'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context)
                          .pushReplacement(fadeSlideRoute(const LoginScreen())),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(
                            text: context.t('register.have_account'),
                            style: const TextStyle(color: AppColors.textMuted)),
                        TextSpan(
                            text: context.t('register.sign_in_link'),
                            style: const TextStyle(
                                color: AppColors.blue,
                                fontWeight: FontWeight.w700)),
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
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.6)),
            const SizedBox(width: 8),
            Text(ar,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted)),
          ],
        ),
      );
}
