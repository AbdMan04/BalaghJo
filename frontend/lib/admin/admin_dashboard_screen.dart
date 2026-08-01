import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../data/api/report_api.dart';
import '../data/models/report.dart';
import '../state/auth_state.dart';
import '../ui/widgets/category_icon.dart';
import '../ui/widgets/status_badge.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ReportApi _api = ReportApi();
  final _search = TextEditingController();

  List<Report> _reports = [];
  bool _loading = true;
  String? _error;

  String? _status;
  String? _category;
  String? _q;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports =
          await _api.adminAll(status: _status, category: _category, q: _q);
      if (!mounted) return;
      setState(() => _reports = reports);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _advance(Report r) async {
    final next = switch (r.status) {
      ReportStatus.pending => 'in_progress',
      ReportStatus.inProgress => 'resolved',
      ReportStatus.resolved => '',
    };
    if (next.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Advance status'),
        content: Text(
            'Move ${r.reportId} from "${r.status.label}" to "${next == 'in_progress' ? 'In Progress' : 'Resolved'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Advance'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.updateStatus(r.id, next);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _logout() async {
    await context.read<AuthState>().logout();
  }

  int _count(ReportStatus s) => _reports.where((r) => r.status == s).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BALAGHJO Admin',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statsRow(),
                const SizedBox(height: 16),
                _filtersRow(),
                const SizedBox(height: 16),
                Expanded(child: _table()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        _statCard('Total', _reports.length, AppColors.navy),
        const SizedBox(width: 12),
        _statCard('Pending', _count(ReportStatus.pending), AppColors.warning),
        const SizedBox(width: 12),
        _statCard(
            'In Progress', _count(ReportStatus.inProgress), AppColors.blue),
        const SizedBox(width: 12),
        _statCard('Resolved', _count(ReportStatus.resolved), AppColors.success),
      ],
    );
  }

  Widget _statCard(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 20)),
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtersRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _dropdown(
          hint: 'Status',
          value: _status,
          items: const [
            ('pending', 'Pending'),
            ('in_progress', 'In Progress'),
            ('resolved', 'Resolved'),
          ],
          onChanged: (v) {
            setState(() => _status = v);
            _load();
          },
        ),
        _dropdown(
          hint: 'Category',
          value: _category,
          items: const [
            ('pothole', 'Pothole'),
            ('waste', 'Waste'),
            ('lighting', 'Lighting'),
            ('other', 'Other'),
          ],
          onChanged: (v) {
            setState(() => _category = v);
            _load();
          },
        ),
        SizedBox(
          width: 280,
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search ID, title, address…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _search.clear();
                        setState(() => _q = null);
                        _load();
                      },
                    ),
            ),
            onSubmitted: (v) {
              setState(() => _q = v.trim().isEmpty ? null : v.trim());
              _load();
            },
          ),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String hint,
    required String? value,
    required List<(String, String)> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Text(hint),
          isDense: true,
          onChanged: (v) => onChanged(v),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('All $hint'),
            ),
            ...items.map(
              (e) => DropdownMenuItem<String?>(value: e.$1, child: Text(e.$2)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _table() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.blue));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_reports.isEmpty) {
      return const Center(child: Text('No reports match your filters'));
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.surface),
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('Report')),
            DataColumn(label: Text('Category')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Address')),
            DataColumn(label: Text('Reporter')),
            DataColumn(label: Text('Submitted')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _reports.map((r) {
            final nextLabel = switch (r.status) {
              ReportStatus.pending => 'Start work',
              ReportStatus.inProgress => 'Mark resolved',
              ReportStatus.resolved => '',
            };
            return DataRow(
              cells: [
                DataCell(Text(r.reportId,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
                DataCell(Text(labelForCategory(r.category, context))),
                DataCell(StatusBadge(r.status)),
                DataCell(ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    r.address.isNotEmpty ? r.address : '—',
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
                DataCell(Text(r.reporterName.isNotEmpty
                    ? '${r.reporterName}\n${r.reporterPhone}'
                    : '—')),
                DataCell(Text(DateFormat.yMMMd().add_Hm().format(r.createdAt))),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (nextLabel.isNotEmpty)
                      SizedBox(
                        height: 34,
                        child: ElevatedButton(
                          onPressed: () => _advance(r),
                          child: Text(nextLabel),
                        ),
                      ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 34,
                      child: OutlinedButton(
                        onPressed: () => _showDetail(r),
                        child: const Text('View'),
                      ),
                    ),
                  ],
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showDetail(Report r) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        title: Text(r.reportId,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                StatusBadge(r.status),
                const SizedBox(width: 8),
                Text(labelForCategory(r.category, ctx)),
              ]),
              const SizedBox(height: 12),
              if (r.description.isNotEmpty) ...[
                const Text('Description',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 4),
                Text(r.description),
                const SizedBox(height: 12),
              ],
              if (r.address.isNotEmpty) ...[
                const Text('Address',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 4),
                Text(r.address),
                const SizedBox(height: 12),
              ],
              if (r.reporterName.isNotEmpty) ...[
                const Text('Reporter',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                    '${r.reporterName}${r.reporterPhone.isNotEmpty ? ' · ${r.reporterPhone}' : ''}'),
                const SizedBox(height: 12),
              ],
              Text(
                  'Submitted ${DateFormat.yMMMd().add_Hm().format(r.createdAt)}',
                  style: const TextStyle(color: AppColors.textMuted)),
              if (r.statusChangedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                    'Last updated ${DateFormat.yMMMd().add_Hm().format(r.statusChangedAt!)}',
                    style: const TextStyle(color: AppColors.textMuted)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
