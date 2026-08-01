// AuthState — application-level session state for feature F1
// (User Authentication).
//
// Single source of truth for "is the user logged in, who are they,
// and is the JWT still valid". Owns bootstrap-from-storage, login,
// register, change-password (FR-3), update-profile
// (FR-3), and logout. Extends ChangeNotifier so it participates in
// Flutter's idiomatic Observer pattern via Provider — widgets call
// context.watch<AuthState>() and rebuild on notifyListeners().
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/firebase_service.dart';
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
        return;
      }
    }
    _syncPush();
    notifyListeners();
  }

  Future<void> login(String identifier, String password) async {
    _setLoading(true);
    try {
      final res = await _api.login(identifier, password);
      await _persist(res.token, res.user);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String password,
    required String phone,
  }) async {
    _setLoading(true);
    try {
      final res = await _api.register(
        firstName: firstName,
        lastName: lastName,
        password: password,
        phone: phone,
      );
      await _persist(res.token, res.user);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    try {
      await _api.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    _setLoading(true);
    try {
      _user = await _api.updateProfile(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    unawaited(FirebaseService.unregisterToken());
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
    _syncPush();
    notifyListeners();
  }

  void _syncPush() {
    if (_token == null) return;
    unawaited(
      FirebaseService.init().then((_) => FirebaseService.registerToken()),
    );
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}
