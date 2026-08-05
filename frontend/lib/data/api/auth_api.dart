import '../models/user.dart';
import 'api_client.dart';

class AuthResult {
  final String token;
  final String refreshToken;
  final AppUser user;
  AuthResult(this.token, this.refreshToken, this.user);
}

class AuthApi {
  final ApiClient _api = ApiClient.instance;

  Future<AuthResult> register({
    required String firstName,
    required String lastName,
    required String password,
    required String phone,
  }) async {
    final res = await _api.post('/api/auth/register', {
      'firstName': firstName,
      'lastName': lastName,
      'password': password,
      'phone': phone,
    });
    return AuthResult(
      res['token'],
      res['refreshToken'],
      AppUser.fromJson(res['user']),
    );
  }

  Future<AuthResult> login(String identifier, String password) async {
    final res = await _api.post('/api/auth/login', {
      'identifier': identifier,
      'password': password,
    });
    return AuthResult(
      res['token'],
      res['refreshToken'],
      AppUser.fromJson(res['user']),
    );
  }

  Future<AppUser> me() async {
    final res = await _api.get('/api/auth/me');
    return AppUser.fromJson(res['user']);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.patch('/api/auth/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<AppUser> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? currentPassword,
  }) async {
    final body = <String, dynamic>{};
    if (firstName != null) body['firstName'] = firstName;
    if (lastName != null) body['lastName'] = lastName;
    if (phone != null) body['phone'] = phone;
    if (currentPassword != null) body['currentPassword'] = currentPassword;
    final res = await _api.patch('/api/auth/profile', body);
    return AppUser.fromJson(res['user']);
  }
}
