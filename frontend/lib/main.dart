import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/firebase_service.dart';
import 'core/locale_state.dart';
import 'core/route_observer.dart';
import 'core/theme.dart';
import 'state/auth_state.dart';
import 'ui/auth/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  // Push plumbing (background handler + listeners) must be registered
  // before the first frame; a no-op on the web dashboard build.
  await FirebaseService.init();
  runApp(const BalaghjoApp());
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
          navigatorObservers: [appRouteObserver],
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
