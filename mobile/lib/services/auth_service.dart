import 'api.dart';
import 'client_context.dart';

class AuthService {
  AuthService(this.api);
  final ApiClient api;

  Future<int> forgotPassword(String email, String language) async {
    final res = await api.post(
      '/api/auth/forgot-password',
      body: {'email': email.trim(), 'language': language},
    );
    return res is Map
        ? ((res['retry_after_seconds'] as num?)?.toInt() ?? 60)
        : 60;
  }

  Future<void> resetPassword({
    required String token,
    required String password,
    required String confirmation,
    String language = 'en',
  }) async {
    await api.post(
      '/api/auth/reset-password',
      body: {
        'token': token,
        'password': password,
        'confirm_password': confirmation,
        'language': language,
      },
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String confirmation,
    String language = 'en',
  }) async {
    await api.post(
      '/api/auth/change-password',
      body: {
        'current_password': currentPassword,
        'password': password,
        'confirm_password': confirmation,
        'language': language,
      },
    );
  }

  Future<String> login({
    required String username,
    required String password,
  }) async {
    final res = await api.post(
      '/api/login',
      body: {'username': username, 'password': password},
    );
    if (res is Map && res['success'] == true && res['token'] is String) {
      return res['token'] as String;
    }
    throw Exception(
      res is Map && res['message'] != null ? res['message'] : 'Login failed',
    );
  }

  Future<String> signup({
    required String username,
    required String email,
    required String password,
  }) async {
    final res = await api.post(
      '/api/signup',
      body: {
        'username': username,
        'email': email,
        'password': password,
        'client_platform': ClientContext.platform,
      },
    );
    if (res is Map && res['success'] == true && res['token'] is String) {
      return res['token'] as String;
    }
    throw Exception(
      res is Map && res['message'] != null ? res['message'] : 'Signup failed',
    );
  }
}
