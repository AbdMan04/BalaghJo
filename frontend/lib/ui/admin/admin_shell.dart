// AdminShell — F5 (Admin Dashboard) landing shell for role=admin users
// on the Flutter web build. A narrow wrapper: hosts the reports table and
// a logout affordance; role gating is enforced upstream (splash/routing)
// and the backend rejects non-admin JWTs on every admin route anyway.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../state/auth_state.dart';
import 'admin_reports_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.location_on, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('BALAGHJO',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2)),
            const SizedBox(width: 8),
            Text(
              context.t('admin.badge'),
              style: const TextStyle(
                color: AppColors.blue,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.t('profile.log_out'),
            onPressed: () => context.read<AuthState>().logout(),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const AdminReportsScreen(),
    );
  }
}