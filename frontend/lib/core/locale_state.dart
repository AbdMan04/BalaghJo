// LocaleState — user-facing language preference (English / Arabic).
// Persisted via shared_preferences so the choice survives restarts.
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleState extends ChangeNotifier {
  static const _kLocale = 'locale';
  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLocale);
    if (code == 'ar' || code == 'en') {
      _locale = Locale(code!);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale l) async {
    if (l == _locale) return;
    _locale = l;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocale, l.languageCode);
  }
}
