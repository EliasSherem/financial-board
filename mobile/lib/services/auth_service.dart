import 'package:flutter/foundation.dart';
import 'api.dart';

class AuthService {
  AuthService(this.api);
  final ApiClient api;

  Future<String> login({required String username, required String password}) async {
    final res = await api.post('/api/login', body: {
      'username': username,
      'password': password,
    });
    if (res is Map && res['success'] == true && res['token'] is String) {
      return res['token'] as String;
    }
    throw Exception(res is Map && res['message'] != null ? res['message'] : 'Login failed');
  }

  Future<String> signup({required String username, required String email, required String password}) async {
    final res = await api.post('/api/signup', body: {
      'username': username,
      'email': email,
      'password': password,
    });
    if (res is Map && res['success'] == true && res['token'] is String) {
      return res['token'] as String;
    }
    throw Exception(res is Map && res['message'] != null ? res['message'] : 'Signup failed');
  }
}

