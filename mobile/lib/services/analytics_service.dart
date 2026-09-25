import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/auth_store.dart';
import 'api.dart';
import 'client_context.dart';

/// Behavioral telemetry only. Financial fields and auth/reset URLs never enter this queue.
class AnalyticsService {
  AnalyticsService._({ApiClient Function(String token)? apiFactory})
    : _apiFactory = apiFactory ?? _defaultApi;
  @visibleForTesting
  factory AnalyticsService.forTesting({
    required ApiClient Function(String token) apiFactory,
  }) => AnalyticsService._(apiFactory: apiFactory);
  static ApiClient _defaultApi(String token) => ApiClient()..setToken(token);
  final ApiClient Function(String token) _apiFactory;
  static final instance = AnalyticsService._();
  static const screens = {
    'dashboard',
    'accounts',
    'transactions',
    'payments',
    'projects',
    'invoices',
    'investments',
    'categories',
    'analytics',
    'ai',
    'receipt',
    'onboarding',
    'settings',
    'momentum',
    'achievements',
    'paywall',
  };
  static const _allowedEvents = {
    'session_started',
    'app_foregrounded',
    'screen_view',
    'feature_used',
    'onboarding_step_completed',
    'paywall_viewed',
    'checkout_started',
    'purchase_pending',
    'purchase_failed',
    'restore_completed',
  };
  final List<Map<String, dynamic>> _queue = [];
  int? _userId;
  String? _token;
  String? _sessionId;
  String? _installId;
  DateTime? _lastInteraction;
  bool _foreground = false;
  bool _ready = false;
  bool _enabled = true;
  bool _sending = false;
  bool _preferenceSending = false;
  bool _preferencePending = false;
  DateTime? _preferencesRead;
  bool get preferencePending => _preferencePending;
  int _generation = 0;
  int _activityGeneration = 0;
  int _preferenceRevision = 0;
  Timer? _timer;
  String _screen = 'dashboard';
  String get _key => 'analytics_queue_v1_$_userId';

  Future<void>? _binding;
  bool get isForeground => _foreground;
  bool get _sessionAvailable {
    final auth = AuthStore.instance;
    return auth != null &&
        auth.isAuthenticated &&
        auth.token == _token &&
        auth.userId == _userId;
  }

  bool get _active => _ready && _foreground && _sessionAvailable;
  bool _current(int generation, int activity) =>
      generation == _generation && activity == _activityGeneration && _active;
  Future<void> bind(AuthStore auth) {
    if (!auth.isInitialized) {
      background();
      return Future<void>.value();
    }
    if (!auth.isAuthenticated) background();
    if (_userId == auth.userId && _token == auth.token) {
      return _binding ?? Future<void>.value();
    }
    return _binding = _bind(auth);
  }

  Future<void> _bind(AuthStore auth) async {
    final oldKey = _key;
    final generation = ++_generation;
    final user = auth.userId;
    background();
    _ready = false;
    _preferenceRevision++;
    _userId = user;
    _token = auth.token;
    _sessionId = null;
    _lastInteraction = null;
    _queue.clear();
    _timer?.cancel();
    _timer = null;
    final sp = await SharedPreferences.getInstance();
    if (generation != _generation) return;
    await sp.remove(oldKey);
    if (generation != _generation) return;
    // Installation ID rotates on account change and after 30 days, never a fingerprint.
    final born = DateTime.tryParse(sp.getString('analytics_install_at') ?? '');
    final previous = sp.getInt('analytics_install_user');
    _installId = sp.getString('analytics_install_id');
    if (_installId == null ||
        previous != _userId ||
        born == null ||
        DateTime.now().difference(born) > const Duration(days: 30)) {
      _installId = clientEventId();
      await sp.setString('analytics_install_id', _installId!);
      if (generation != _generation) return;
      await sp.setString(
        'analytics_install_at',
        DateTime.now().toUtc().toIso8601String(),
      );
      if (generation != _generation) return;
      if (user == null) {
        await sp.remove('analytics_install_user');
      } else {
        await sp.setInt('analytics_install_user', user);
      }
    }
    if (generation != _generation) return;
    _enabled = sp.getBool('analytics_enabled_${_userId ?? 'anon'}') ?? true;
    _preferencePending =
        sp.getBool('analytics_preference_pending_$_userId') ?? false;
    _preferencesRead = null;
    if (_userId == null || _token == null) return;
    final raw = sp.getString(_key);
    if (raw != null) {
      try {
        _queue.addAll(
          (jsonDecode(raw) as List)
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .take(100),
        );
      } catch (_) {
        /* Invalid local cache. */
      }
    }
    await ClientContext.refresh();
    if (generation != _generation) return;
    _ready = true;
    if (_foreground) _activateForeground();
  }

  bool get enabled => _enabled;
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    _preferencePending = true;
    final generation = _generation, revision = ++_preferenceRevision;
    final user = _userId;
    final key = _key;
    if (!value) _queue.clear();
    final sp = await SharedPreferences.getInstance();
    if (generation != _generation || revision != _preferenceRevision) return;
    await sp.setBool('analytics_enabled_${user ?? 'anon'}', value);
    await sp.setBool('analytics_preference_pending_$user', true);
    if (generation != _generation || revision != _preferenceRevision) return;
    if (!value) await sp.remove(key);
    if (generation != _generation || revision != _preferenceRevision) return;
    await refreshPreferences(force: true);
  }

  Future<void> refreshPreferences({bool force = false}) async {
    if (!_active || _token == null || _userId == null || _preferenceSending) {
      return;
    }
    if (!force &&
        !_preferencePending &&
        _preferencesRead != null &&
        DateTime.now().difference(_preferencesRead!) <
            const Duration(minutes: 1)) {
      return;
    }
    final generation = _generation, user = _userId;
    final activity = _activityGeneration, revision = _preferenceRevision;
    final key = _key;
    final value = _enabled;
    final pending = _preferencePending;
    final api = _apiFactory(_token!);
    _preferenceSending = true;
    try {
      final result =
          pending
              ? await api.post(
                '/api/analytics/preferences',
                body: {'enabled': value},
              )
              : await api.get('/api/analytics/preferences');
      if (!_current(generation, activity) ||
          revision != _preferenceRevision ||
          value != _enabled) {
        return;
      }
      if (result is Map && result['enabled'] is bool) {
        final enabled = result['enabled'] as bool;
        _enabled = enabled;
        _preferencePending = false;
        _preferencesRead = DateTime.now();
        final sp = await SharedPreferences.getInstance();
        if (!_current(generation, activity) ||
            revision != _preferenceRevision) {
          return;
        }
        await sp.setBool('analytics_enabled_$user', enabled);
        if (!_current(generation, activity) ||
            revision != _preferenceRevision) {
          return;
        }
        await sp.remove('analytics_preference_pending_$user');
        if (!_current(generation, activity) ||
            revision != _preferenceRevision) {
          return;
        }
        if (!enabled) {
          _queue.clear();
          await sp.remove(key);
        }
      }
    } catch (_) {
      /* Local opt-out stays effective while its server update waits for connectivity. */
    } finally {
      if (generation == _generation && activity == _activityGeneration) {
        _preferenceSending = false;
      }
    }
  }

  void foreground() {
    if (!_sessionAvailable) {
      background();
      return;
    }
    if (_foreground) return;
    _foreground = true;
    if (_ready) _activateForeground();
  }

  void _activateForeground() {
    if (!_active) return;
    _timer ??= Timer.periodic(const Duration(minutes: 1), (_) {
      if (!_active) {
        background();
        return;
      }
      unawaited(refreshPreferences());
      unawaited(flush());
    });
    unawaited(refreshPreferences());
    if (_userId == null || !_enabled) return;
    _ensureSession();
    _enqueue('app_foregrounded', const {});
    unawaited(flush());
  }

  void background() {
    _foreground = false;
    _activityGeneration++;
    _timer?.cancel();
    _timer = null;
    _sending = false;
    _preferenceSending = false;
  }

  void _ensureSession() {
    final now = DateTime.now();
    if (_sessionId == null ||
        _lastInteraction == null ||
        now.difference(_lastInteraction!) >= const Duration(minutes: 30)) {
      _sessionId = clientEventId();
      _enqueue('session_started', const {});
    }
    _lastInteraction = now;
  }

  void screen(String name) {
    if (!screens.contains(name)) return;
    _screen = name;
    event('screen_view');
  }

  void event(
    String name, {
    String? feature,
    String? step,
    String? flowId,
    String? outcome,
  }) {
    if (!_enabled ||
        !_active ||
        _userId == null ||
        !_allowedEvents.contains(name)) {
      return;
    }
    _ensureSession();
    _enqueue(name, {
      if (feature != null && screens.contains(feature)) 'feature': feature,
      if (step != null &&
          {
            'account',
            'transactions',
            'categories',
            'payment',
            'insight',
            'review',
          }.contains(step))
        'step': step,
      if (flowId != null && RegExp(r'^[a-f0-9-]{36}$').hasMatch(flowId))
        'flow_id': flowId,
      if (outcome != null &&
          {
            'canceled',
            'network',
            'pending',
            'failed',
            'success',
          }.contains(outcome))
        'outcome': outcome,
    });
    unawaited(flush());
  }

  void _enqueue(String name, Map<String, dynamic> metadata) {
    if (!_active || !_enabled || _userId == null || _token == null) return;
    _queue.add({
      'event_id': clientEventId(),
      'schema_version': 1,
      'event_type': name,
      'session_id': _sessionId,
      'install_id': _installId,
      'client_platform': ClientContext.platform,
      'app_version': ClientContext.appVersion,
      'app_build': ClientContext.build,
      'source_screen': _screen,
      'client_occurred_at': DateTime.now().toUtc().toIso8601String(),
      'metadata': metadata,
    });
    if (_queue.length > 100) _queue.removeAt(0);
    unawaited(_persist());
  }

  Future<void> _persist() async {
    if (_userId == null) return;
    final generation = _generation, user = _userId;
    final key = _key, payload = jsonEncode(_queue);
    final sp = await SharedPreferences.getInstance();
    if (generation != _generation || !_enabled) return;
    await sp.setString(key, payload);
    if ((generation != _generation && _userId != user) || !_enabled) {
      await sp.remove(key);
    }
  }

  Future<void> flush() async {
    if (!_active || _sending || !_enabled || _queue.isEmpty || _token == null) {
      return;
    }
    final generation = _generation;
    final activity = _activityGeneration;
    _queue.removeWhere((e) {
      final time = DateTime.tryParse(e['client_occurred_at'] as String? ?? '');
      return time == null ||
          DateTime.now().toUtc().difference(time) > const Duration(hours: 24);
    });
    if (_queue.isEmpty) return;
    final batch = _queue.take(20).toList();
    _sending = true;
    try {
      await _apiFactory(
        _token!,
      ).post('/api/analytics/events', body: {'events': batch});
      if (!_current(generation, activity) || !_enabled) return;
      final ids = batch.map((e) => e['event_id']).toSet();
      _queue.removeWhere((e) => ids.contains(e['event_id']));
      await _persist();
    } on ApiException catch (e) {
      if (_current(generation, activity) &&
          _enabled &&
          (e.statusCode == 400 || e.statusCode == 413)) {
        final ids = batch.map((e) => e['event_id']).toSet();
        _queue.removeWhere((e) => ids.contains(e['event_id']));
        await _persist();
      }
    } catch (_) {
      /* Stable IDs are retained for a bounded offline retry. */
    } finally {
      if (generation == _generation && activity == _activityGeneration) {
        _sending = false;
      }
    }
  }
}
