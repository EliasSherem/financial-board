import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api.dart';
import '../services/analytics_service.dart';
import '../services/client_context.dart';
import '../state/auth_store.dart';
import 'models.dart';
import 'service.dart';

/// Server-owned progress; persisted client cache never awards XP or completes missions.
class MomentumStore extends ChangeNotifier {
  MomentumStore({MomentumService Function(String token)? serviceFactory})
    : _serviceFactory = serviceFactory ?? MomentumService.new;
  final MomentumService Function(String token) _serviceFactory;
  MomentumState? state;
  bool loading = false;
  bool offline = false;
  String? error;
  int? _userId;
  String? _token;
  int _generation = 0;
  int _identityGeneration = 0;
  bool _suspended = true;
  Future<void>? _restoring;
  Future<void>? _refreshing;
  int _snapshotRevision = 0;
  int _cacheRevision = 0;
  final Map<String, String> _seenAcknowledgments = {};
  DateTime? _refreshed;
  final List<Json> _pending = [];
  Timer? _refreshTimer;
  Timer? _debounce;
  bool _flushing = false;
  bool _refreshRequested = false;
  bool presentationOpen = false;
  bool momentumOpen = false;
  final Set<String> presented = {};
  String get _cacheKey => 'momentum_v1_$_userId';
  String get _pendingKey => 'momentum_pending_v1_$_userId';
  bool get isSuspended => _suspended;
  MomentumService? get service =>
      _suspended || _token == null || _userId == null
          ? null
          : _serviceFactory(_token!);

  /// A pause invalidates network responses, not this account's local progress.
  void suspend() {
    final changed = !_suspended || loading || _refreshRequested;
    _suspended = true;
    _generation++;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _debounce?.cancel();
    _debounce = null;
    loading = false;
    _refreshing = null;
    _flushing = false;
    _refreshRequested = false;
    if (changed) notifyListeners();
  }

  Future<void> bind(AuthStore auth) async {
    if (!auth.isInitialized) {
      suspend();
      return;
    }
    if (_userId != auth.userId || _token != auth.token) {
      _bindIdentity(auth);
    }
    if (!auth.isAuthenticated) {
      suspend();
      await _restoring;
      return;
    }
    final generation = _generation;
    await _restoring;
    if (generation != _generation || !auth.isAuthenticated || !_suspended) {
      return;
    }
    _suspended = false;
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final end = DateTime.tryParse(state?.week['ends_at'] as String? ?? '');
      if (end != null && !DateTime.now().toUtc().isBefore(end)) {
        unawaited(refresh());
      }
    });
    // A mutation may have happened while paused, even if the token is unchanged.
    await refresh();
  }

  void _bindIdentity(AuthStore auth) {
    final oldCache = _cacheKey, oldPending = _pendingKey;
    final oldUser = _userId;
    _generation++;
    final identity = ++_identityGeneration;
    _suspended = true;
    _token = auth.token;
    _userId = auth.userId;
    _refreshTimer?.cancel();
    _debounce?.cancel();
    state = null;
    _pending.clear();
    presented.clear();
    _seenAcknowledgments.clear();
    _refreshed = null;
    loading = false;
    _refreshing = null;
    _flushing = false;
    _refreshRequested = false;
    offline = false;
    error = null;
    presentationOpen = false;
    _restoring = _restoreLocal(identity, oldUser, oldCache, oldPending);
    notifyListeners();
  }

  Future<void> _restoreLocal(
    int identity,
    int? oldUser,
    String oldCache,
    String oldPending,
  ) async {
    final sp = await SharedPreferences.getInstance();
    if (oldUser != null) {
      await sp.remove(oldCache);
      await sp.remove(oldPending);
    }
    if (identity != _identityGeneration || _token == null || _userId == null) {
      return;
    }
    try {
      final cache = sp.getString(_cacheKey);
      if (cache != null) {
        final restored = MomentumState(object(jsonDecode(cache)));
        if (restored.userId == _userId) state = restored;
      }
      final pending = sp.getString(_pendingKey);
      if (pending != null) {
        _pending.addAll((jsonDecode(pending) as List).map(object));
      }
    } catch (_) {
      /* Stale or corrupt cache is replaced from the server. */
    }
    notifyListeners();
  }

  Future<void> refresh({bool force = true}) {
    if (_suspended || _token == null || _userId == null) return Future.value();
    if (_refreshing != null) return _refreshing!;
    final periodEnd = DateTime.tryParse(
      state?.week['ends_at'] as String? ?? '',
    );
    if (!force &&
        !offline &&
        (periodEnd == null || DateTime.now().toUtc().isBefore(periodEnd)) &&
        _refreshed != null &&
        DateTime.now().difference(_refreshed!) < const Duration(seconds: 30)) {
      return Future.value();
    }
    final generation = _generation;
    final completion = Completer<void>();
    // Publish the future before notifying listeners, so reentrant callers join it.
    _refreshing = completion.future;
    unawaited(() async {
      try {
        await _readProgress(generation);
        completion.complete();
      } catch (error, stack) {
        completion.completeError(error, stack);
      }
    }());
    return completion.future;
  }

  Future<void> _readProgress(int generation) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      do {
        if (_suspended || generation != _generation) return;
        _refreshRequested = false;
        _debounce?.cancel();
        _debounce = null;
        final revision = _snapshotRevision;
        try {
          final result = await service!.me();
          if (generation != _generation) return;
          // A completed POST already carries a newer authoritative snapshot.
          if (revision == _snapshotRevision || _isNewerSnapshot(result)) {
            await _accept(result);
          }
          if (generation != _generation) return;
          unawaited(_flush());
        } catch (_) {
          if (generation != _generation) return;
          if (revision == _snapshotRevision) {
            offline = true;
            error = 'unavailable';
          }
        }
      } while (_refreshRequested);
    } finally {
      if (generation == _generation) {
        _refreshing = null;
        loading = false;
        notifyListeners();
      }
    }
  }

  void financialMutation() {
    if (_suspended) return;
    _debounce?.cancel();
    if (loading) {
      // Unlike another reader, a mutation can make the in-flight snapshot stale.
      _refreshRequested = true;
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () => refresh());
  }

  bool _isNewerSnapshot(MomentumState result) {
    final incoming = DateTime.tryParse('${result.json['generated_at']}');
    final current = DateTime.tryParse('${state?.json['generated_at']}');
    return incoming != null && current != null && incoming.isAfter(current);
  }

  Future<void> _accept(MomentumState result) async {
    if (_suspended || result.userId != _userId) return;
    final incoming = DateTime.tryParse('${result.json['generated_at']}');
    final current = DateTime.tryParse('${state?.json['generated_at']}');
    if (incoming != null && current != null && incoming.isBefore(current)) {
      return;
    }
    final generation = _generation;
    if (_seenAcknowledgments.isNotEmpty) {
      result = MomentumState({
        ...result.json,
        'achievements': [
          for (final achievement in result.achievements)
            if (achievement.completed &&
                !achievement.seen &&
                _seenAcknowledgments.containsKey(achievement.key))
              {
                ...achievement.json,
                'seen_at': _seenAcknowledgments[achievement.key],
              }
            else
              achievement.json,
        ],
      });
    }
    final previous = state;
    if (previous != null) {
      const steps = {
        'activation_first_account': 'account',
        'activation_first_transactions': 'transactions',
        'activation_categories': 'categories',
        'activation_first_payment': 'payment',
        'activation_first_insight': 'insight',
        'activation_weekly_review': 'review',
      };
      final completedBefore =
          previous.missions.where((m) => m.completed).map((m) => m.key).toSet();
      for (final mission in result.missions.where(
        (m) => m.completed && m.scope == 'activation',
      )) {
        if (!completedBefore.contains(mission.key) &&
            steps.containsKey(mission.key)) {
          AnalyticsService.instance.event(
            'onboarding_step_completed',
            step: steps[mission.key],
          );
        }
      }
    }
    state = result;
    _snapshotRevision++;
    _refreshed = DateTime.now();
    offline = false;
    error = null;
    notifyListeners();
    await _persistState(generation);
  }

  Future<void> _persistState(int generation) async {
    if (generation != _generation || state == null) return;
    final revision = ++_cacheRevision, user = _userId;
    final key = _cacheKey, payload = jsonEncode(state!.json);
    final sp = await SharedPreferences.getInstance();
    if (generation != _generation || revision != _cacheRevision) return;
    await sp.setString(key, payload);
    if (generation != _generation) {
      if (_userId != user) await sp.remove(key);
      return;
    }
  }

  Future<void> event(
    String type, {
    Json fields = const {},
    bool queueOnFailure = true,
  }) async {
    if (_suspended) return;
    if (type == 'backfill_seen') {
      presented.addAll(
        state?.achievements.where((a) => a.completed).map((a) => a.key) ??
            const <String>[],
      );
    }
    final generation = _generation;
    final svc = service;
    if (svc == null) return;
    final payload = {
      'event_id': clientEventId(),
      'type': type,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      ...fields,
    };
    try {
      final result = await svc.event(payload);
      if (generation == _generation) {
        await _accept(result);
      }
    } catch (_) {
      if (generation != _generation || _suspended) return;
      if (!queueOnFailure) rethrow;
      _pending.add(payload);
      if (_pending.length > 30) _pending.removeAt(0);
      await _persistQueue();
    }
  }

  Future<void> _persistQueue() async {
    if (_userId == null) return;
    final identity = _identityGeneration, user = _userId;
    final key = _pendingKey, payload = jsonEncode(_pending);
    final sp = await SharedPreferences.getInstance();
    if (identity != _identityGeneration) return;
    await sp.setString(key, payload);
    if (identity != _identityGeneration && _userId != user) {
      await sp.remove(key);
    }
  }

  Future<void> _flush() async {
    if (_suspended || _flushing || service == null) return;
    _flushing = true;
    final generation = _generation;
    final svc = service!;
    try {
      for (final payload in List<Json>.from(_pending)) {
        if (generation != _generation) break;
        final at = DateTime.tryParse(payload['occurred_at'] as String? ?? '');
        if (at == null ||
            DateTime.now().toUtc().difference(at) >
                const Duration(minutes: 15)) {
          _pending.remove(payload);
          continue;
        }
        try {
          final result = await svc.event(payload);
          if (generation != _generation) break;
          _pending.remove(payload);
          await _accept(result);
        } on ApiException catch (e) {
          if (generation != _generation) break;
          if (e.statusCode >= 400 &&
              e.statusCode < 500 &&
              e.statusCode != 429) {
            _pending.remove(payload);
          } else {
            break;
          }
        } catch (_) {
          break;
        }
      }
      if (generation == _generation) await _persistQueue();
    } finally {
      if (generation == _generation) _flushing = false;
    }
  }

  Future<void> markSeen(String key) async {
    final generation = _generation;
    final svc = service;
    if (svc == null) return;
    await svc.seen(key);
    if (generation != _generation || _suspended || state == null) return;
    if (!state!.achievements.any((a) => a.key == key && a.completed)) return;
    // Persist only display metadata after the server ACK. This is not a new
    // progress snapshot and must not suppress a pending authoritative read.
    final seenAt = _seenAcknowledgments.putIfAbsent(
      key,
      () => DateTime.now().toUtc().toIso8601String(),
    );
    state = MomentumState({
      ...state!.json,
      'achievements': [
        for (final achievement in state!.achievements)
          if (achievement.key == key &&
              achievement.completed &&
              !achievement.seen)
            {...achievement.json, 'seen_at': seenAt}
          else
            achievement.json,
      ],
    });
    notifyListeners();
    await _persistState(generation);
  }

  Future<void> acceptReview(Future<MomentumState> request) async {
    final generation = _generation;
    final active = !_suspended;
    final result = await request;
    if (active && !_suspended && generation == _generation) {
      await _accept(result);
    }
  }

  @override
  void dispose() {
    _suspended = true;
    _generation++;
    _identityGeneration++;
    _refreshTimer?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}
