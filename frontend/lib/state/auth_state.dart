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
  static const _kRefreshToken = 'refresh_token';

  String? _token;
  String? _refreshToken;
  AppUser? _user;
  bool _loading = false;

  String? get token => _token;
  AppUser? get user => _user;
  bool get isAuthenticated => _token != null;
  bool get loading => _loading;

  Future<void> bootstrap() async {
    // Expired-session hook: ApiClient auto-refreshes on 401; if the refresh
    // token is itself dead it calls this so we clear persisted state.
    ApiClient.instance.onSessionExpired = () => _clearSession();

    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_kToken);
    _refreshToken = prefs.getString(_kRefreshToken);
    ApiClient.instance.setTokens(_token, _refreshToken);
    if (_token != null) {
      try {
        // Runs through ApiClient, which silently refreshes a stale access
        // token and retries before this /me ever fails.
        _user = await _api.me();
      } catch (_) {
        await _clearSession();
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
      await _persist(res.token, res.refreshToken, res.user);
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
      await _persist(res.token, res.refreshToken, res.user);
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
      // Backend revokes every refresh token on a password change; drop ours
      // so the next expiry signs the session out instead of failing refresh.
      await _clearRefreshToken();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? currentPassword,
  }) async {
    _setLoading(true);
    try {
      _user = await _api.updateProfile(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        currentPassword: currentPassword,
      );
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    unawaited(FirebaseService.unregisterToken());
    // Best-effort server-side revocation; local session clears regardless.
    unawaited(ApiClient.instance.logoutRemote());
    await _clearSession();
  }

  Future<void> _persist(String token, String refreshToken, AppUser user) async {
    _token = token;
    _refreshToken = refreshToken;
    _user = user;
    ApiClient.instance.setTokens(token, refreshToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kRefreshToken, refreshToken);
    _syncPush();
    notifyListeners();
  }

  Future<void> _clearRefreshToken() async {
    _refreshToken = null;
    ApiClient.instance.setTokens(_token, null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRefreshToken);
  }

  Future<void> _clearSession() async {
    _token = null;
    _refreshToken = null;
    _user = null;
    ApiClient.instance.setTokens(null, null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kRefreshToken);
    notifyListeners();
  }

  void _syncPush() {
    if (_token == null) return;
    // On the web dashboard only admins need pushes (new-report alerts); a
    // citizen opening the site shouldn't be asked for notification access.
    if (kIsWeb && _user?.role != 'admin') return;
    unawaited(
      FirebaseService.init().then((_) => FirebaseService.registerToken()),
    );
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}
