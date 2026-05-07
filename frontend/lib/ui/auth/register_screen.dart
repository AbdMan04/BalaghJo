import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../state/auth_state.dart';
import '../home/main_shell.dart';
import '../widgets/animations.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _pass = TextEditingController();
  final _shake = ValueNotifier<int>(0);
  bool _usePhone = true;
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
            email: _usePhone ? null : _email.text.trim().toLowerCase(),
            password: _pass.text,
            phone: _usePhone ? _phone.text.trim() : null,
          );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
          fadeSlideRoute(const MainShell()), (_) => false);
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
    _email.dispose();
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
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
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
                    child: _SegmentedToggle(
                      isPhone: _usePhone,
                      onChanged: (v) => setState(() => _usePhone = v),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _usePhone
                          ? Column(
                              key: const ValueKey('phone'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label(context.t('register.phone_label')),
                                TextFormField(
                                  controller: _phone,
                                  decoration: InputDecoration(
                                    hintText: context.t('register.phone_hint'),
                                    prefixIcon: const Icon(Icons.phone_android, color: AppColors.textMuted),
                                  ),
                                  keyboardType: TextInputType.phone,
                                  validator: (v) =>
                                      (v == null || v.trim().length < 6) ? context.t('login.invalid_phone') : null,
                                ),
                              ],
                            )
                          : Column(
                              key: const ValueKey('email'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label(context.t('register.email_label')),
                                TextFormField(
                                  controller: _email,
                                  decoration: InputDecoration(
                                    hintText: context.t('register.email_hint'),
                                    prefixIcon: const Icon(Icons.mail_outline, color: AppColors.textMuted),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    final s = v?.trim() ?? '';
                                    final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s);
                                    return ok ? null : context.t('login.invalid_email');
                                  },
                                ),
                              ],
                            ),
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
                              _label(context.t('register.first_name')),
                              TextFormField(
                                controller: _first,
                                decoration: InputDecoration(hintText: context.t('register.first_hint')),
                                validator: (v) => (v == null || v.trim().isEmpty) ? context.t('common.required') : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label(context.t('register.last_name')),
                              TextFormField(
                                controller: _last,
                                decoration: InputDecoration(hintText: context.t('register.last_hint')),
                                validator: (v) => (v == null || v.trim().isEmpty) ? context.t('common.required') : null,
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
                        _label(context.t('register.password')),
                        TextFormField(
                          controller: _pass,
                          decoration: InputDecoration(
                            hintText: context.t('register.password_hint'),
                            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: AppColors.textMuted),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          obscureText: _obscure,
                          validator: (v) => (v == null || v.length < 6) ? context.t('register.password_min') : null,
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
                    delay: const Duration(milliseconds: 400),
                    child: PressableScale(
                      onTap: loading ? null : _submit,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.navy, AppColors.blue],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.blue.withValues(alpha: 0.35),
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
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  context.t('register.sign_up'),
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
                          fadeSlideRoute(const LoginScreen())),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: context.t('register.have_account'), style: const TextStyle(color: AppColors.textMuted)),
                        TextSpan(text: context.t('register.sign_in_link'), style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w700)),
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

class _SegmentedToggle extends StatelessWidget {
  final bool isPhone;
  final ValueChanged<bool> onChanged;
  const _SegmentedToggle({required this.isPhone, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: isPhone ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6),
                  ],
                ),
              ),
            ),
          ),
          Builder(builder: (ctx) {
            return Row(
              children: [
                _seg(ctx.t('register.toggle_phone'), Icons.phone_android, isPhone, () => onChanged(true)),
                _seg(ctx.t('register.toggle_email'), Icons.mail_outline, !isPhone, () => onChanged(false)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _seg(String label, IconData icon, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Icon(icon,
                    key: ValueKey('$label-$active'),
                    size: 16,
                    color: active ? AppColors.navy : AppColors.textMuted),
              ),
              const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.navy : AppColors.textMuted,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

