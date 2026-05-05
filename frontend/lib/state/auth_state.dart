import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/api/api_client.dart';
import '../data/api/auth_api.dart';
import '../data/models/user.dart';

class AuthState extends ChangeNotifier {
  final AuthApi _api = AuthApi();
  static const _kToken = 'token';

  String? _token;
  AppUser? _user;
  bool _loading = false;

  String? get token => _token;
  AppUser? get user => _user;
  bool get isAuthenticated => _token != null;
  bool get loading => _loading;

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_kToken);
    if (_token != null) {
      ApiClient.instance.setToken(_token);
      try {
        _user = await _api.me();
      } catch (_) {
        await logout();
      }
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _setLoading(true);
    try {
      final res = await _api.login(email, password);
      await _persist(res.token, res.user);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
  }) async {
    _setLoading(true);
    try {
      final res = await _api.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        phone: phone,
      );
      await _persist(res.token, res.user);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    _token = null;
    _user = null;
    ApiClient.instance.setToken(null);
    notifyListeners();
  }

  Future<void> _persist(String token, AppUser user) async {
    _token = token;
    _user = user;
    ApiClient.instance.setToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    notifyListeners();
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}
