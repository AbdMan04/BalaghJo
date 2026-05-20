/* SubmitReportScreen — feature F2 (Issue Report Submission).
- Drives the core report-creation flow: category selection (FR-4,
 optionally pre-filled from a Quick Report card on the home screen),
 photo capture via camera or gallery (FR-5), GPS auto-detection
 within 5–10s with manual-pin fallback (NFR-3), reverse geocoding
 for a human-readable address, title, and required description
 (FR-6).
 */
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/report_api.dart';
import '../widgets/animations.dart';
import '../widgets/category_icon.dart';
import 'map_picker_screen.dart';

class SubmitReportScreen extends StatefulWidget {
  final String? initialCategory;
  const SubmitReportScreen({super.key, this.initialCategory});

  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  final _api = ReportApi();
  final _description = TextEditingController();
  final _address = TextEditingController();
  late String _category = widget.initialCategory ?? 'pothole';
  File? _photo;
  double? _lat;
  double? _lng;
  bool _busy = false;
  bool _success = false;
  String? _error;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (x != null) setState(() => _photo = File(x.path));
  }

  Future<void> _openMap() async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(initialLat: _lat, initialLng: _lng),
      ),
    );
    if (picked != null) {
      setState(() {
        _lat = picked.lat;
        _lng = picked.lng;
        if (picked.address != null && picked.address!.isNotEmpty && _address.text.trim().isEmpty) {
          _address.text = picked.address!;
        }
      });
    }
  }

  Future<void> _captureLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 10));
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_description.text.trim().length < 5) {
      setState(() => _error = context.t('submit.desc_min'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_lat == null) await _captureLocation();
      await _api.create(
        category: _category,
        description: _description.text.trim(),
        address: _address.text.trim(),
        lat: _lat,
        lng: _lng,
        photo: _photo,
      );
      if (!mounted) return;
      setState(() => _success = true);
      await Future.delayed(const Duration(milliseconds: 1100));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(context.t('submit.success')),
          ]),
        ),
      );
      _description.clear();
      _address.clear();
      setState(() {
        _photo = null;
        _category = 'pothole';
        _success = false;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('submit.title'), style: const TextStyle(fontWeight: FontWeight.w800))),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeSlideIn(child: _label(context.t('submit.photo'))),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 60),
                  child: PressableScale(
                    onTap: _pickPhoto,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: _photo != null ? AppColors.blue : AppColors.border,
                          width: _photo != null ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        child: _photo != null
                            ? ClipRRect(
                                key: const ValueKey('photo'),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                child: Image.file(_photo!, fit: BoxFit.cover, width: double.infinity),
                              )
                            : Column(
                                key: const ValueKey('empty'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: const BoxDecoration(
                                      color: AppColors.surface,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.camera_alt_outlined, size: 28, color: AppColors.blue),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(context.t('submit.tap_photo'), style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text(context.t('submit.photo_hint'),
                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                FadeSlideIn(delay: const Duration(milliseconds: 120), child: _label(context.t('submit.problem_type'))),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 160),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: ReportCategory.userSelectable.map((c) {
                      final selected = _category == c.apiValue;
                      return PressableScale(
                        onTap: () => setState(() => _category = c.apiValue),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? c.tint.withValues(alpha: 0.12) : Colors.white,
                            border: Border.all(
                              color: selected ? c.tint : AppColors.border,
                              width: selected ? 1.5 : 1,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            boxShadow: selected
                                ? [BoxShadow(color: c.tint.withValues(alpha: 0.25), blurRadius: 10)]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: Icon(c.icon,
                                    key: ValueKey('${c.apiValue}-$selected'),
                                    size: 16,
                                    color: selected ? c.tint : AppColors.navy),
                              ),
                              const SizedBox(width: 6),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 220),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: selected ? c.tint : AppColors.navy,
                                  fontSize: 13,
                                ),
                                child: Text(c.label),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                FadeSlideIn(delay: const Duration(milliseconds: 200), child: _label(context.t('submit.description'))),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 240),
                  child: TextField(
                    controller: _description,
                    maxLines: 4,
                    decoration: InputDecoration(hintText: context.t('submit.description_hint')),
                  ),
                ),
                FadeSlideIn(delay: const Duration(milliseconds: 280), child: _label(context.t('submit.location'))),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 320),
                  child: TextField(
                    controller: _address,
                    decoration: InputDecoration(
                      hintText: context.t('submit.address_hint'),
                      prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.blue),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 360),
                  child: PressableScale(
                    onTap: _openMap,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: _lat != null ? AppColors.blue : AppColors.border,
                          width: _lat != null ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: const Icon(Icons.map_outlined, color: AppColors.blue, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_lat == null ? context.t('submit.pick_on_map') : context.t('submit.location_selected'),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(
                                  _lat == null
                                      ? context.t('submit.pick_on_map_hint')
                                      : 'Lat ${_lat!.toStringAsFixed(4)}, Lng ${_lng!.toStringAsFixed(4)}',
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 400),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _captureLocation,
                      icon: const Icon(Icons.my_location, size: 16, color: AppColors.blue),
                      label: Text(context.t('submit.use_my_location'),
                          style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w700)),
                    ),
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
                  delay: const Duration(milliseconds: 380),
                  child: PressableScale(
                    onTap: _busy ? null : _submit,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 54,
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
                        child: _busy
                            ? const SizedBox(
                                key: ValueKey('l'),
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : Row(
                                key: const ValueKey('t'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(context.t('submit.submit_button'),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_success)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.elasticOut,
                    builder: (_, v, __) => Transform.scale(
                      scale: v,
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle, color: AppColors.success, size: 80),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.6)),
      );
}
