import 'package:flutter/widgets.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/push_service.dart';

class AuthStore extends ChangeNotifier {
  AuthStore({Future<SharedPreferences> Function()? preferencesLoader})
    : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance {
    instance = this;
  }
  static AuthStore? instance;
  final Future<SharedPreferences> Function() _preferencesLoader;
  Future<void>? _loadFuture;
  Future<void> _storageWrites = Future<void>.value();
  int _sessionGeneration = 0;
  int _externalActivityCount = 0;
  final Set<_ExternalActivityResumeWaiter> _externalResumeWaiters = {};
  bool _initialized = false;
  bool _restoring = false;
  String? _loadError;
  bool _disposed = false;
  String? _token;
  int? _userId;
  bool _isPro = false;
  String? _userName;
  bool _biometricEnabled = false;
  bool _locked = false;

  String? get token => _token;
  int? get userId => _userId;
  bool get isPro => _isPro;
  bool get isProOrExempt => isPro;
  String get userName => _userName ?? 'user';

  bool get hasToken => _token != null && _token!.isNotEmpty;
  bool get biometricEnabled => _biometricEnabled;
  bool get isLocked => _locked;
  bool get isInitialized => _initialized;
  bool get isRestoring => _restoring;
  String? get loadError => _loadError;
  bool get isAuthenticated => _initialized && hasToken && !_locked;
  bool get isExternalActivityActive => _externalActivityCount > 0;

  /// Keep a user-requested native handoff bound to the current unlocked session.
  /// This in-memory scope never exempts a cold start from biometric protection.
  Future<T> runExternalActivity<T>(Future<T> Function() action) async {
    if (_disposed || !isAuthenticated) {
      throw StateError('Unlock the app before opening an external activity.');
    }
    final generation = _sessionGeneration;
    bool sameSession() =>
        !_disposed && generation == _sessionGeneration && isAuthenticated;
    _externalActivityCount++;
    late T result;
    try {
      notifyListeners();
      if (!sameSession()) {
        throw StateError('The session changed before the external activity.');
      }
      try {
        result = await action();
      } finally {
        // Android can deliver the Activity result before Flutter receives
        // resumed. Preserve the scope through that handoff, including errors.
        if (sameSession()) await _waitForExternalActivityResume();
      }
    } finally {
      if (!_disposed && generation == _sessionGeneration) {
        _externalActivityCount--;
        notifyListeners();
      }
    }
    // Ending the scope may itself notify a listener that locks or changes the
    // session. Validate after that notification before exposing its result.
    if (!sameSession()) {
      throw StateError('The session changed during the external activity.');
    }
    return result;
  }

  Future<void> _waitForExternalActivityResume() async {
    final binding = WidgetsBinding.instance;
    if (binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed) {
      return;
    }
    final waiter = _ExternalActivityResumeWaiter(binding);
    _externalResumeWaiters.add(waiter);
    try {
      await waiter.finished;
    } finally {
      _externalResumeWaiters.remove(waiter);
      waiter.finish();
    }
  }

  void _resetExternalActivities() {
    _externalActivityCount = 0;
    for (final waiter in _externalResumeWaiters.toList()) {
      waiter.finish();
    }
    _externalResumeWaiters.clear();
  }

  Future<void> load() {
    if (_initialized) return Future<void>.value();
    final pending = _loadFuture;
    if (pending != null) return pending;
    _restoring = true;
    _loadError = null;
    final generation = _sessionGeneration;
    late final Future<void> request;
    request = _restore(generation).whenComplete(() {
      if (identical(_loadFuture, request)) _loadFuture = null;
    });
    _loadFuture = request;
    notifyListeners();
    return request;
  }

  Future<void> _restore(int generation) async {
    try {
      await _storageWrites;
      final sp = await _preferencesLoader();
      final token = sp.getString('auth_token');
      final biometricEnabled = sp.getBool('biometric_enabled') ?? false;
      final savedLock = sp.getBool('auth_locked') ?? false;
      // Read all persisted values before committing any restored session.
      final profile = _tokenProfile(token);
      final verifiedPro =
          profile.userId == null
              ? null
              : sp.getBool('verified_pro_${profile.userId}');
      if (_disposed || generation != _sessionGeneration) return;
      _token = token;
      _biometricEnabled = biometricEnabled;
      // Unlocking applies to the running session, never to a cold start.
      _locked = hasToken && (biometricEnabled || savedLock);
      _userId = profile.userId;
      _userName = profile.userName;
      _isPro = verifiedPro ?? profile.isPro;
      _initialized = true;
    } catch (_) {
      if (_disposed || generation != _sessionGeneration) return;
      // A read failure is retryable and must never erase stored credentials.
      _loadError = 'session_restore_failed';
    } finally {
      if (!_disposed && generation == _sessionGeneration) {
        _restoring = false;
        notifyListeners();
      }
    }
  }

  Future<void> _persist(
    Future<void> Function(SharedPreferences preferences) write,
  ) {
    final operation = _storageWrites.then((_) async {
      final preferences = await _preferencesLoader();
      await write(preferences);
    });
    // Keep subsequent writes ordered even if one storage operation fails.
    _storageWrites = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> setToken(String? token) async {
    final generation = ++_sessionGeneration;
    _resetExternalActivities();
    final oldUser = _userId;
    final nextToken = token == null || token.isEmpty ? null : token;
    _token = nextToken;
    _locked = false;
    _parseToken();
    _initialized = true;
    _restoring = false;
    _loadError = null;
    final persisted = _persist((sp) async {
      await sp.remove('is_pro_local');
      if (oldUser != null) await sp.remove('verified_pro_$oldUser');
      if (nextToken == null) {
        await sp.remove('auth_token');
      } else {
        await sp.setString('auth_token', nextToken);
      }
      await sp.remove('auth_locked');
    });
    notifyListeners();
    await persisted;
    if (!_disposed && generation == _sessionGeneration && nextToken != null) {
      unawaited(_syncPushToken());
    }
  }

  Future<void> invalidateToken(String rejectedToken) async {
    if (_token == rejectedToken) await logout(force: true);
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
    final persisted = _persist((sp) async {
      await sp.setBool('auth_locked', true);
    });
    notifyListeners();
    await persisted;
  }

  Future<bool> unlock({required String expectedToken}) async {
    if (!_initialized || !hasToken || _token != expectedToken) return false;
    final generation = _sessionGeneration;
    _locked = false;
    final persisted = _persist((sp) async {
      await sp.remove('auth_locked');
    });
    notifyListeners();
    await persisted;
    return !_disposed && generation == _sessionGeneration && !_locked;
  }

  Future<void> setBiometricEnabled(bool value) async {
    _biometricEnabled = value;
    if (!value && _locked) {
      _locked = false;
    }
    final persisted = _persist((sp) async {
      await sp.setBool('biometric_enabled', value);
      if (!value) await sp.remove('auth_locked');
    });
    notifyListeners();
    await persisted;
  }

  Future<void> _syncPushToken() async {
    try {
      await PushService.instance.syncTokenWithBackend();
    } catch (_) {
      // ignore sync errors
    }
  }

  void _parseToken() {
    final profile = _tokenProfile(_token);
    _userId = profile.userId;
    _isPro = profile.isPro;
    _userName = profile.userName;
  }

  ({int? userId, bool isPro, String? userName}) _tokenProfile(String? token) {
    int? userId;
    bool isPro = false;
    String? userName;
    if (token == null || token.isEmpty) {
      return (userId: null, isPro: false, userName: null);
    }
    try {
      final parts = token.split('.');
      if (parts.length >= 2) {
        String normalized = parts[1].replaceAll('-', '+').replaceAll('_', '/');
        while (normalized.length % 4 != 0) {
          normalized += '=';
        }
        final payload = utf8.decode(base64.decode(normalized));
        final map = jsonDecode(payload) as Map<String, dynamic>;
        final id = map['id'] ?? map['user_id'] ?? map['sub'];
        if (id is int) {
          userId = id;
        } else if (id is String) {
          userId = int.tryParse(id);
        }
        final pro = map['is_pro'] ?? map['isPro'] ?? map['pro'];
        if (pro is bool) {
          isPro = pro;
        } else if (pro is int) {
          isPro = pro != 0;
        } else if (pro is String) {
          isPro = pro.toLowerCase() == 'true' || pro == '1';
        }
        final uname =
            map['username'] ??
            map['name'] ??
            map['user'] ??
            map['preferred_username'];
        if (uname is String && uname.isNotEmpty) {
          userName = uname;
        }
      }
    } catch (_) {
      // ignore decoding errors; defaults remain
    }
    return (userId: userId, isPro: isPro, userName: userName);
  }

  Future<void> setLocalPro(bool value) async {
    // Compatibility for old purchase callers; only verified server state grants Pro.
    await _persist((sp) async {
      await sp.remove('is_pro_local');
    });
  }

  // Update Pro flag from server (e.g., after Stripe/Play sync).
  void setServerPro(bool value) {
    _isPro = value;
    final user = _userId;
    final token = _token;
    if (user != null) {
      unawaited(
        _persist((sp) async {
          if (_userId == user && _token == token && hasToken) {
            await sp.setBool('verified_pro_$user', value);
          }
        }).catchError((Object _) {
          // Server state remains authoritative if its optional cache fails.
        }),
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionGeneration++;
    _resetExternalActivities();
    if (identical(instance, this)) instance = null;
    super.dispose();
  }
}

class _ExternalActivityResumeWaiter with WidgetsBindingObserver {
  _ExternalActivityResumeWaiter(this.binding) {
    binding.addObserver(this);
  }

  final WidgetsBinding binding;
  final _completion = Completer<void>();
  Future<void> get finished => _completion.future;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) finish();
  }

  void finish() {
    if (_completion.isCompleted) return;
    binding.removeObserver(this);
    _completion.complete();
  }
}
