// AdminReportDetailScreen — F5 / FR-15..16 for the dashboard.
//
// FR-15: the detailed view shows the attached photo and a map pin at the
// stored GPS coordinates, with a copy-coordinates button.
// FR-16: a status dropdown enforces the controlled workflow
// (Pending -> In Progress -> Resolved) and fires the admin-only PATCH.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/config.dart';
import '../../core/locale_state.dart';
import '../../core/map_config.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/admin_api.dart';
import '../../data/models/report.dart';
import '../../state/auth_state.dart';
import '../widgets/category_icon.dart';
import '../widgets/status_badge.dart';

class AdminReportDetailScreen extends StatefulWidget {
  final Report report;
  const AdminReportDetailScreen({super.key, required this.report});

  @override
  State<AdminReportDetailScreen> createState() => _AdminReportDetailScreenState();
}

class _AdminReportDetailScreenState extends State<AdminReportDetailScreen> {
  late Report _report = widget.report;
  bool _saving = false;
  String? _error;

  // FR-16 controlled workflow: a report can only move forward
  // (Pending -> In Progress -> Resolved). The dropdown offers the current
  // status (selected) plus the valid next one, so admins can't skip or
  // regress, and the backend independently enforces it too.
  static const _forward = {
    ReportStatus.pending: [ReportStatus.pending, ReportStatus.inProgress],
    ReportStatus.inProgress: [ReportStatus.inProgress, ReportStatus.resolved],
    ReportStatus.resolved: [ReportStatus.resolved],
  };

  bool get _isTerminal => _report.status == ReportStatus.resolved;

  Future<void> _changeStatus(ReportStatus next) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    // Resolve localized text before the await: build-time t() uses
    // context.watch, which is illegal from an async event handler.
    final successMsg = AppStrings.ofLocaleState(
        context.read<LocaleState>(), 'admin.status_updated');
    try {
      final updated = await AdminApi().updateStatus(_report.id, next.apiValue);
      if (!mounted) return;
      setState(() {
        _report = updated;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          content: Text(successMsg),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  Future<void> _copyCoords() async {
    final copiedMsg = AppStrings.ofLocaleState(
        context.read<LocaleState>(), 'admin.coords_copied');
    await Clipboard.setData(ClipboardData(text: '${_report.lat}, ${_report.lng}'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        content: Text(copiedMsg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = ReportCategory.fromApi(_report.category);
    return Scaffold(
      appBar: AppBar(
        title: Text(_report.reportId, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton.icon(
            onPressed: () => context.read<AuthState>().logout(),
            icon: const Icon(Icons.logout, size: 18),
            label: Text(context.t('profile.log_out')),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo (FR-15).
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: _report.photoUrl.isNotEmpty
                  ? Image.network(
                      AppConfig.imageUrl(_report.photoUrl),
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 220,
                        color: cat.tileBg,
                        alignment: Alignment.center,
                        child: Icon(cat.icon, color: cat.tint, size: 56),
                      ),
                    )
                  : Container(
                      height: 220,
                      color: cat.tileBg,
                      alignment: Alignment.center,
                      child: Icon(cat.icon, color: cat.tint, size: 56),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                StatusBadge(_report.status, large: true),
                const Spacer(),
                Text(
                  _date(_report.createdAt),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _sectionTitle(context.t('detail.report_info'), [
              _kv(context, context.t('detail.category'), cat.label),
              _kv(context, context.t('detail.submitted_on'), _date(_report.createdAt)),
              if (_report.updatedAt != null)
                _kv(context, context.t('detail.last_updated'), _date(_report.updatedAt!)),
              _kv(context, context.t('detail.assigned_to'), _report.assignedTo.isEmpty ? '—' : _report.assignedTo),
            ]),
            const SizedBox(height: 16),
            _sectionTitle(context.t('detail.reporter_contact'), [
              _kv(context, 'Name', _report.reporterName.isEmpty ? '—' : _report.reporterName),
              _kv(context, context.t('profile.phone'), _report.reporterPhone.isEmpty ? '—' : _report.reporterPhone),
            ]),
            const SizedBox(height: 16),
            _sectionTitle(context.t('detail.user_description'), [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  _report.description.isEmpty ? '—' : _report.description,
                  style: const TextStyle(color: AppColors.textMuted, height: 1.5),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                ),
              ),
            // Map pin at the stored coordinates (FR-15).
            _mapCard(context),
            const SizedBox(height: 16),
            _sectionTitle(context.t('admin.status_workflow'), [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: _isTerminal
                    ? const SizedBox(
                        height: 52,
                        child: Center(
                          child: Text('Resolved', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                        ),
                      )
                    : InputDecorator(
                        decoration: InputDecoration(
                          labelText: context.t('admin.change_status'),
                          prefixIcon: const Icon(
                            Icons.swap_horiz_rounded,
                            color: AppColors.textMuted,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<ReportStatus>(
                            key: const ValueKey('admin-status-dropdown'),
                            value: _report.status,
                            isExpanded: true,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            items: [
                              for (final s in _forward[_report.status] ?? const [])
                                DropdownMenuItem(
                                  value: s,
                                  child: Text(s.bilingualLabel,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                            ],
                            onChanged: _saving ? null : (s) {
                              if (s != null && s != _report.status) _changeStatus(s);
                            },
                          ),
                        ),
                      ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.textMuted),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...children,
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _mapCard(BuildContext context) {
    final hasCoords = _report.lat != 0 && _report.lng != 0;
    return _sectionTitle(context.t('admin.location'), [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (hasCoords)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(_report.lat, _report.lng),
                      initialZoom: MapConfig.locationZoom,
                      minZoom: MapConfig.minZoom,
                      maxZoom: MapConfig.maxZoom,
                      cameraConstraint: MapConfig.cameraConstraint(),
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom),
                    ),
                    children: [
                      MapConfig.tileLayer(),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_report.lat, _report.lng),
                            width: 34,
                            height: 34,
                            child: const Icon(Icons.location_pin, color: AppColors.danger, size: 34),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              const Text('—'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_report.lat.toStringAsFixed(6)}, ${_report.lng.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
                TextButton.icon(
                  onPressed: _copyCoords,
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(context.t('admin.copy_coords')),
                ),
              ],
            ),
          ],
        ),
      ),
    ]);
  }

  String _date(DateTime d) {
    final local = d.toLocal();
    return '${local.day} ${_month(local.month)} ${local.year}';
  }

  String _month(int m) => ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
}