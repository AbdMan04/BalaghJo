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
    required String email,
    required String password,
    String? phone,
  }) async {
    final res = await _api.post('/api/auth/register', {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
    return AuthResult(res['token'], AppUser.fromJson(res['user']));
  }

  Future<AuthResult> login(String email, String password) async {
    final res = await _api.post('/api/auth/login', {'email': email, 'password': password});
    return AuthResult(res['token'], AppUser.fromJson(res['user']));
  }

  Future<AppUser> me() async {
    final res = await _api.get('/api/auth/me');
    return AppUser.fromJson(res['user']);
  }
}
