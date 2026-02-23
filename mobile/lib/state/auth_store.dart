import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/push_service.dart';

class AuthStore extends ChangeNotifier {
  String? _token;
  int? _userId;
  bool _isPro = false;
  bool _localPro = false;
  String? _userName;
  bool _biometricEnabled = false;
  bool _locked = false;

  String? get token => _token;
  int? get userId => _userId;
  bool get isPro => _isPro || _localPro;
  bool get isProOrExempt => isPro || _userId == 1 || _userId == 3;
  String get userName => _userName ?? 'user';

  bool get hasToken => _token != null && _token!.isNotEmpty;
  bool get biometricEnabled => _biometricEnabled;
  bool get isLocked => _locked;
  bool get isAuthenticated => hasToken && !_locked;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _token = sp.getString('auth_token');
    _localPro = sp.getBool('is_pro_local') ?? false;
    _biometricEnabled = sp.getBool('biometric_enabled') ?? false;
    _locked = hasToken ? (sp.getBool('auth_locked') ?? false) : false;
    _parseToken();
    notifyListeners();
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final sp = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await sp.remove('auth_token');
      _locked = false;
      await sp.remove('auth_locked');
    } else {
      await sp.setString('auth_token', token);
      _locked = false;
      await sp.remove('auth_locked');
    }
    _parseToken();
    notifyListeners();
    if (token != null && token.isNotEmpty) {
      unawaited(_syncPushToken());
    }
  }

  Future<void> logout({bool force = false}) async {
    if (!force && _biometricEnabled && hasToken) {
      await lock();
      return;
    }
    await setToken(null);
  }

  Future<void> lock() async {
    if (!hasToken) return;
    _locked = true;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('auth_locked', true);
    notifyListeners();
  }

  Future<void> unlock() async {
    _locked = false;
    final sp = await SharedPreferences.getInstance();
    await sp.remove('auth_locked');
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool value) async {
    _biometricEnabled = value;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('biometric_enabled', value);
    if (!value && _locked) {
      _locked = false;
      await sp.remove('auth_locked');
    }
    notifyListeners();
  }

  Future<void> _syncPushToken() async {
    try {
      await PushService.instance.syncTokenWithBackend();
    } catch (_) {
      // ignore sync errors
    }
  }

  void _parseToken() {
    _userId = null;
    _isPro = false;
    _userName = null;
    final t = _token;
    if (t == null || t.isEmpty) return;
    try {
      final parts = t.split('.');
      if (parts.length >= 2) {
        String normalized = parts[1].replaceAll('-', '+').replaceAll('_', '/');
        while (normalized.length % 4 != 0) {
          normalized += '=';
        }
        final payload = utf8.decode(base64.decode(normalized));
        final map = jsonDecode(payload) as Map<String, dynamic>;
        final id = map['id'] ?? map['user_id'] ?? map['sub'];
        if (id is int) {
          _userId = id;
        } else if (id is String) {
          _userId = int.tryParse(id);
        }
        final pro = map['is_pro'] ?? map['isPro'] ?? map['pro'];
        if (pro is bool) {
          _isPro = pro;
        } else if (pro is int) {
          _isPro = pro != 0;
        } else if (pro is String) {
          _isPro = pro.toLowerCase() == 'true' || pro == '1';
        }
        final uname = map['username'] ?? map['name'] ?? map['user'] ?? map['preferred_username'];
        if (uname is String && uname.isNotEmpty) {
          _userName = uname;
        }
      }
    } catch (_) {
      // ignore decoding errors; defaults remain
    }
  }

  Future<void> setLocalPro(bool value) async {
    _localPro = value;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('is_pro_local', value);
    notifyListeners();
  }

  // Update Pro flag from server (e.g., after Stripe/Play sync).
  void setServerPro(bool value) {
    _isPro = value;
    notifyListeners();
  }
}
