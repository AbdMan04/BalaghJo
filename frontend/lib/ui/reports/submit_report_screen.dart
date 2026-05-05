import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../data/api/report_api.dart';
import '../widgets/animations.dart';

class SubmitReportScreen extends StatefulWidget {
  const SubmitReportScreen({super.key});

  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  final _api = ReportApi();
  final _description = TextEditingController();
  final _address = TextEditingController();
  String _category = 'pothole';
  File? _photo;
  double? _lat;
  double? _lng;
  bool _busy = false;
  bool _success = false;
  String? _error;

  static const _cats = [
    ('pothole', 'Pothole', Icons.warning_amber_rounded),
    ('waste', 'Waste', Icons.delete_outline),
    ('lighting', 'Lighting', Icons.lightbulb_outline),
    ('road_crack', 'Road Crack', Icons.alt_route),
  ];

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (x != null) setState(() => _photo = File(x.path));
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
      setState(() => _error = 'Please add a longer description (5+ chars)');
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
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Report submitted successfully'),
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
      appBar: AppBar(title: const Text('Submit Report', style: TextStyle(fontWeight: FontWeight.w800))),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeSlideIn(child: _label('PHOTO')),
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
                                  const Text('Tap to add photo', style: TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  const Text('JPG, PNG up to 10MB',
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                FadeSlideIn(delay: const Duration(milliseconds: 120), child: _label('PROBLEM TYPE')),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 160),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _cats.map((c) {
                      final selected = _category == c.$1;
                      return PressableScale(
                        onTap: () => setState(() => _category = c.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.blue.withValues(alpha: 0.1) : Colors.white,
                            border: Border.all(
                              color: selected ? AppColors.blue : AppColors.border,
                              width: selected ? 1.5 : 1,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            boxShadow: selected
                                ? [BoxShadow(color: AppColors.blue.withValues(alpha: 0.2), blurRadius: 10)]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: Icon(c.$3,
                                    key: ValueKey('${c.$1}-$selected'),
                                    size: 16,
                                    color: selected ? AppColors.blue : AppColors.navy),
                              ),
                              const SizedBox(width: 6),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 220),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: selected ? AppColors.blue : AppColors.navy,
                                  fontSize: 13,
                                ),
                                child: Text(c.$2),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                FadeSlideIn(delay: const Duration(milliseconds: 200), child: _label('DESCRIPTION')),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 240),
                  child: TextField(
                    controller: _description,
                    maxLines: 4,
                    decoration: const InputDecoration(hintText: 'Describe the problem in detail…'),
                  ),
                ),
                FadeSlideIn(delay: const Duration(milliseconds: 280), child: _label('LOCATION')),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 320),
                  child: TextField(
                    controller: _address,
                    decoration: InputDecoration(
                      hintText: 'Al-Yamouk Street, Block 5',
                      prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.blue),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.my_location, size: 20, color: AppColors.blue),
                        onPressed: _captureLocation,
                      ),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: _lat != null
                      ? Padding(
                          key: const ValueKey('gps'),
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.gps_fixed, size: 14, color: AppColors.success),
                              const SizedBox(width: 6),
                              Text('GPS: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
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
                            : const Row(
                                key: ValueKey('t'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Submit Report',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
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
