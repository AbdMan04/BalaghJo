// AdminAnnouncementsScreen — mass messaging (broadcasts). Lists the
// announcement history (GET /api/admin/announcements) and lets an admin
// compose a new broadcast to all users, to the reporters of a category,
// or to a single phone number. Recipients receive an in-app Notification
// row and an FCM push (when the backend has Firebase configured).
import 'package:flutter/material.dart';
import '../../core/date_format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/admin_api.dart';
import '../../data/models/announcement.dart';
import '../widgets/category_icon.dart';
import '../widgets/remote_view.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() => _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  final _api = AdminApi();
  final _listKey = GlobalKey<RemoteViewState<List<AdminAnnouncement>>>();
  bool _sending = false;

  Future<void> _compose() async {
    final result = await showDialog<_AnnouncementDraft>(
      context: context,
      builder: (_) => const _ComposeDialog(),
    );
    if (result == null || !mounted) return;
    setState(() => _sending = true);
    try {
      final sent = await _api.sendAnnouncement(
        title: result.title,
        body: result.body,
        audienceType: result.audience.apiValue,
        category: result.category,
        phone: result.phone,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('admin.announce_sent').replaceAll('{n}', '${sent.recipients}'))),
      );
      _listKey.currentState?.reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.t('admin.announcements_sub'),
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _sending ? null : _compose,
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
                icon: const Icon(Icons.campaign, size: 18),
                label: Text(context.t('admin.announce_new')),
              ),
            ],
          ),
        ),
        Expanded(
          child: RemoteView<List<AdminAnnouncement>>(
            key: _listKey,
            load: _api.listAnnouncements,
            isEmpty: (l) => l.isEmpty,
            emptyMessage: context.t('admin.announce_empty'),
            emptyIcon: Icons.campaign_outlined,
            builder: (context, list) => ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _AnnouncementCard(announcement: list[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnnouncementDraft {
  final String title;
  final String body;
  final AnnouncementAudience audience;
  final String? category;
  final String? phone;
  const _AnnouncementDraft({
    required this.title,
    required this.body,
    required this.audience,
    this.category,
    this.phone,
  });
}

class _ComposeDialog extends StatefulWidget {
  const _ComposeDialog();

  @override
  State<_ComposeDialog> createState() => _ComposeDialogState();
}

class _ComposeDialogState extends State<_ComposeDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _phone = TextEditingController();
  AnnouncementAudience _audience = AnnouncementAudience.all;
  ReportCategory _category = ReportCategory.pothole;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    final phone = _phone.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() => _error = _errorText(context));
      return;
    }
    if (_audience == AnnouncementAudience.user && phone.isEmpty) {
      setState(() => _error = _errorText(context));
      return;
    }
    Navigator.of(context).pop(_AnnouncementDraft(
      title: title,
      body: body,
      audience: _audience,
      category: _audience == AnnouncementAudience.category ? _category.apiValue : null,
      phone: _audience == AnnouncementAudience.user ? phone : null,
    ));
  }

  String _errorText(BuildContext context) => context.t('admin.announce_error');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('admin.announce_compose')),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: context.t('admin.announce_title'),
                  hintText: context.t('admin.announce_title_hint'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _body,
                maxLines: 4,
                maxLength: 2000,
                decoration: InputDecoration(
                  labelText: context.t('admin.announce_message'),
                  hintText: context.t('admin.announce_message_hint'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.t('admin.announce_audience'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<AnnouncementAudience>(
                initialValue: _audience,
                decoration: const InputDecoration(isDense: true),
                items: const [
                  DropdownMenuItem(value: AnnouncementAudience.all, child: Text('All users')),
                  DropdownMenuItem(value: AnnouncementAudience.category, child: Text('Users who reported a category')),
                  DropdownMenuItem(value: AnnouncementAudience.user, child: Text('A single user')),
                ],
                onChanged: (v) => setState(() => _audience = v ?? AnnouncementAudience.all),
              ),
              const SizedBox(height: 12),
              if (_audience == AnnouncementAudience.category)
                DropdownButtonFormField<ReportCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    for (final c in ReportCategory.userSelectable)
                      DropdownMenuItem(value: c, child: Text(c.label)),
                  ],
                  onChanged: (v) => setState(() => _category = v ?? ReportCategory.pothole),
                ),
              if (_audience == AnnouncementAudience.user)
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: context.t('admin.announce_phone'),
                    hintText: context.t('admin.announce_phone_hint'),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
          child: Text(context.t('admin.announce_send')),
        ),
      ],
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final AdminAnnouncement announcement;
  const _AnnouncementCard({required this.announcement});

  @override
  Widget build(BuildContext context) {
    final audLabel = switch (announcement.audience) {
      AnnouncementAudience.all => context.t('admin.aud_all'),
      AnnouncementAudience.category =>
        '${context.t('admin.aud_category')}: ${ReportCategory.fromApi(announcement.audienceCategory).label}',
      AnnouncementAudience.user =>
        '${context.t('admin.aud_user')}: ${announcement.audienceUserId ?? '-'}',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  announcement.title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              Text(
                formatDate(announcement.createdAt),
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(announcement.body, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _meta(context, Icons.groups_outlined, audLabel),
              _meta(context, Icons.people_alt_outlined,
                  '${announcement.recipients} ${context.t('admin.announce_recipients')}'),
              if (announcement.sentBy.isNotEmpty)
                _meta(context, Icons.person_outline, announcement.sentBy),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      );
}
