import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/locale_state.dart';
import '../core/theme.dart';
import '../state/auth_state.dart';
import 'admin_dashboard_screen.dart';
import 'admin_login_screen.dart';

void main() {
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()..bootstrap()),
        ChangeNotifierProvider(create: (_) => LocaleState()..bootstrap()),
      ],
      child: MaterialApp(
        title: 'BALAGHJO Admin',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    if (!auth.isAuthenticated) return const AdminLoginScreen();
    return const AdminDashboardScreen();
  }
}
