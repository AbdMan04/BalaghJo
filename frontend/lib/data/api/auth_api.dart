import '../models/user.dart';
import 'api_client.dart';

class AuthResult {
  final String token;
  final AppUser user;
  AuthResult(this.token, this.user);
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
    return AuthResult(res['token'], AppUser.fromJson(res['user']));
  }

  Future<AuthResult> login(String identifier, String password) async {
    final res = await _api.post('/api/auth/login', {
      'identifier': identifier,
      'password': password,
    });
    return AuthResult(res['token'], AppUser.fromJson(res['user']));
  }

  Future<AppUser> me() async {
    final res = await _api.get('/api/auth/me');
    return AppUser.fromJson(res['user']);
  }

  Future<AppUser> verify(String code) async {
    final res = await _api.post('/api/auth/verify', {'code': code});
    return AppUser.fromJson(res['user']);
  }

  Future<void> resendCode() async {
    await _api.post('/api/auth/resend-code', {});
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
  }) async {
    final body = <String, dynamic>{};
    if (firstName != null) body['firstName'] = firstName;
    if (lastName != null) body['lastName'] = lastName;
    if (phone != null) body['phone'] = phone;
    final res = await _api.patch('/api/auth/profile', body);
    return AppUser.fromJson(res['user']);
  }
}
