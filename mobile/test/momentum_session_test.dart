import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/momentum/models.dart';
import 'package:mobile/momentum/service.dart';
import 'package:mobile/momentum/store.dart';
import 'package:mobile/services/api.dart';
import 'package:mobile/state/auth_store.dart';

class SessionAuth extends AuthStore {
  bool initialized = true;
  bool unlocked = false;
  String? sessionToken = 'session-fixture';
  int? sessionUser = 7;

  @override
  bool get isInitialized => initialized;
  @override
  bool get isAuthenticated => initialized && hasToken && unlocked;
  @override
  bool get hasToken => sessionToken != null;
  @override
  String? get token => sessionToken;
  @override
  int? get userId => sessionUser;
}

MomentumState progress(int xp) => MomentumState({
  'enabled': true,
  'user_id': 7,
  'lifetime_xp': xp,
  'week': {
    'ends_at':
        DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
  },
  'missions': <Json>[],
  'achievements': <Json>[],
});

Json pendingEvent() => {
  'event_id': '44b0e777-af6b-480a-bb4a-994fe0cc349b',
  'type': 'coachmark_seen',
  'occurred_at': DateTime.now().toUtc().toIso8601String(),
};

class SessionMomentumService extends MomentumService {
  SessionMomentumService() : super('session-fixture');
  int reads = 0;
  int seenCalls = 0;
  final List<Json> events = [];
  Future<MomentumState> Function(int)? read;
  Future<MomentumState> Function(int, Json)? sendEvent;

  @override
  Future<MomentumState> me() {
    reads++;
    return read?.call(reads) ?? Future.value(progress(100 + reads));
  }

  @override
  Future<MomentumState> event(Json payload) {
    events.add(payload);
    return sendEvent?.call(events.length, payload) ??
        Future.value(progress(150));
  }

  @override
  Future<void> seen(String key) async {
    seenCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'locked cold start preserves cached progress and pending events without any requests',
    (tester) async {
      final cached = progress(90);
      final queued = jsonEncode([pendingEvent()]);
      SharedPreferences.setMockInitialValues({
        'momentum_v1_7': jsonEncode(cached.json),
        'momentum_pending_v1_7': queued,
      });
      final auth = SessionAuth();
      final service = SessionMomentumService();
      var factories = 0;
      final store = MomentumStore(
        serviceFactory: (_) {
          factories++;
          return service;
        },
      );
      addTearDown(store.dispose);
      addTearDown(auth.dispose);

      await store.bind(auth);
      expect(store.state?.xp, 90);
      expect(store.isSuspended, isTrue);
      expect(store.service, isNull);
      await store.refresh();
      await store.event('coachmark_seen');
      await store.markSeen('account_organizer');
      store.financialMutation();
      await tester.pump(const Duration(minutes: 2));

      final prefs = await SharedPreferences.getInstance();
      expect(factories, 0);
      expect(service.reads, 0);
      expect(service.events, isEmpty);
      expect(service.seenCalls, 0);
      expect(store.loading, isFalse);
      expect(prefs.getString('momentum_v1_7'), jsonEncode(cached.json));
      expect(prefs.getString('momentum_pending_v1_7'), queued);
    },
  );

  test(
    'a response arriving after suspend cannot replace cached progress; same identity resumes',
    () async {
      SharedPreferences.setMockInitialValues({
        'momentum_v1_7': jsonEncode(progress(90).json),
      });
      final auth = SessionAuth()..unlocked = true;
      final oldResponse = Completer<MomentumState>();
      final service =
          SessionMomentumService()
            ..read =
                (call) =>
                    call == 1
                        ? oldResponse.future
                        : Future.value(progress(111));
      final store = MomentumStore(serviceFactory: (_) => service);
      addTearDown(store.dispose);
      addTearDown(auth.dispose);

      final binding = store.bind(auth);
      await Future<void>.delayed(Duration.zero);
      expect(store.loading, isTrue);
      store.suspend();
      oldResponse.complete(progress(999));
      await binding;
      expect(store.loading, isFalse);
      expect(store.state?.xp, 90);
      expect(store.error, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(
        MomentumState(object(jsonDecode(prefs.getString('momentum_v1_7')!))).xp,
        90,
      );

      await store.bind(auth);
      expect(store.isSuspended, isFalse);
      expect(service.reads, 2);
      expect(store.state?.xp, 111);
      await store.bind(auth);
      expect(
        service.reads,
        2,
        reason: 'Binding an already active identity does not duplicate reads',
      );
    },
  );

  test(
    'suspending during local restoration keeps the cache and resumes only once',
    () async {
      SharedPreferences.setMockInitialValues({
        'momentum_v1_7': jsonEncode(progress(90).json),
      });
      final auth = SessionAuth()..unlocked = true;
      final service = SessionMomentumService();
      final store = MomentumStore(serviceFactory: (_) => service);
      addTearDown(store.dispose);
      addTearDown(auth.dispose);

      final binding = store.bind(auth);
      store.suspend();
      await binding;
      expect(service.reads, 0);
      expect(store.state?.xp, 90);
      await Future.wait([store.bind(auth), store.bind(auth)]);
      expect(service.reads, 1);
      expect(store.state?.xp, 101);
    },
  );

  testWidgets(
    'pause cancels mutation and week timers, and resume refreshes even with unchanged token',
    (tester) async {
      final auth = SessionAuth()..unlocked = true;
      final service = SessionMomentumService();
      final store = MomentumStore(serviceFactory: (_) => service);
      addTearDown(store.dispose);
      addTearDown(auth.dispose);
      await store.bind(auth);
      expect(service.reads, 1);
      store.financialMutation();
      store.suspend();
      await tester.pump(const Duration(minutes: 2));
      expect(service.reads, 1);
      await store.bind(auth);
      expect(service.reads, 2);
      store.suspend();
    },
  );

  test(
    'late rejected flush cannot discard queued events or disturb a resumed flush',
    () async {
      final event = pendingEvent();
      SharedPreferences.setMockInitialValues({
        'momentum_pending_v1_7': jsonEncode([event]),
      });
      final auth = SessionAuth()..unlocked = true;
      final first = Completer<MomentumState>();
      final second = Completer<MomentumState>();
      final service =
          SessionMomentumService()
            ..sendEvent = (call, _) => call == 1 ? first.future : second.future;
      final store = MomentumStore(serviceFactory: (_) => service);
      addTearDown(store.dispose);
      addTearDown(auth.dispose);
      await store.bind(auth);
      await Future<void>.delayed(Duration.zero);
      expect(service.events.length, 1);
      store.suspend();
      await store.bind(auth);
      await Future<void>.delayed(Duration.zero);
      expect(service.events.length, 2);
      first.completeError(ApiException(400, 'Old request rejected'));
      await Future<void>.delayed(Duration.zero);
      await store.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(
        service.events.length,
        2,
        reason: 'The old finally must not clear the new flush guard',
      );
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('momentum_pending_v1_7')!), [event]);
      expect(service.events[0]['event_id'], service.events[1]['event_id']);
      second.complete(progress(180));
      await Future<void>.delayed(Duration.zero);
      expect(store.state?.xp, 180);
      expect(jsonDecode(prefs.getString('momentum_pending_v1_7')!), isEmpty);
    },
  );

  test(
    'uninitialized auth suspends without logout; explicit empty session clears cache and queue',
    () async {
      SharedPreferences.setMockInitialValues({
        'momentum_v1_7': jsonEncode(progress(90).json),
        'momentum_pending_v1_7': jsonEncode([pendingEvent()]),
      });
      final auth = SessionAuth();
      final service = SessionMomentumService();
      final store = MomentumStore(serviceFactory: (_) => service);
      addTearDown(store.dispose);
      addTearDown(auth.dispose);
      await store.bind(auth);
      auth.initialized = false;
      await store.bind(auth);
      expect(store.state?.xp, 90);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('momentum_pending_v1_7'), isNotNull);

      auth
        ..initialized = true
        ..sessionToken = null
        ..sessionUser = null;
      await store.bind(auth);
      expect(store.state, isNull);
      expect(store.service, isNull);
      expect(service.reads, 0);
      expect(service.events, isEmpty);
      expect(prefs.getString('momentum_v1_7'), isNull);
      expect(prefs.getString('momentum_pending_v1_7'), isNull);
    },
  );
}
