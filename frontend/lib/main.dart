import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'admin/admin_main.dart';
import 'core/locale_state.dart';
import 'core/theme.dart';
import 'state/auth_state.dart';
import 'ui/auth/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb && _isAdminRoute()) {
    runApp(const AdminApp());
    return;
  }
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  runApp(const BalaghjoApp());
}

// Served from web/admin.html (or any path ending in /admin) the same build
// boots the desktop admin dashboard instead of the mobile app.
bool _isAdminRoute() {
  final path = Uri.base.path;
  return path.endsWith('admin.html') || path.endsWith('/admin');
}

class BalaghjoApp extends StatelessWidget {
  const BalaghjoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(
          create: (_) => LocaleState()..bootstrap(),
        ),
      ],
      child: Consumer<LocaleState>(
        builder: (context, locale, _) => MaterialApp(
          title: 'BALAGHJO',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          locale: locale.locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
