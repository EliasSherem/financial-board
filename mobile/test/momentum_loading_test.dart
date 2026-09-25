import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/momentum/models.dart';
import 'package:mobile/momentum/store.dart';

import 'momentum_session_test.dart'
    show SessionAuth, SessionMomentumService, progress;

MomentumState currentProgress(int xp) => MomentumState({
  ...progress(xp).json,
  'week': {
    'ends_at':
        DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String(),
  },
});

class _DelayedSeenService extends SessionMomentumService {
  final acknowledgment = Completer<void>();
  @override
  Future<void> seen(String key) => acknowledgment.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'cached progress stays available while simultaneous readers share one request and completion',
    () async {
      SharedPreferences.setMockInitialValues({
        'momentum_v1_7': jsonEncode(currentProgress(90).json),
      });
      final auth = SessionAuth()..unlocked = true;
      final response = Completer<MomentumState>();
      final service = SessionMomentumService()..read = (_) => response.future;
      final store = MomentumStore(serviceFactory: (_) => service);
      addTearDown(store.dispose);
      addTearDown(auth.dispose);
      final binding = store.bind(auth);
      await Future<void>.delayed(Duration.zero);
      expect(store.state?.xp, 90);
      expect(store.loading, isTrue);
      var joinedFinished = false;
      final joined = store.refresh().then((_) => joinedFinished = true);
      final passive = store.refresh(force: false);
      await Future<void>.delayed(Duration.zero);
      expect(service.reads, 1);
      expect(joinedFinished, isFalse);
      response.complete(currentProgress(110));
      await Future.wait([binding, joined, passive]);
      expect(service.reads, 1);
      expect(joinedFinished, isTrue);
      expect(store.state?.xp, 110);
      expect(store.loading, isFalse);
    },
  );

  test(
    'opening a fresh profile reuses progress, explicit refresh and expiry still read',
    () async {
      final auth = SessionAuth()..unlocked = true;
      final service =
          SessionMomentumService()
            ..read = (call) async => currentProgress(100 + call);
      final store = MomentumStore(serviceFactory: (_) => service);
      addTearDown(store.dispose);
      addTearDown(auth.dispose);
      await store.bind(auth);
      await store.refresh(force: false);
      await store.refresh(force: false);
      expect(service.reads, 1);
      await store.refresh();
      expect(service.reads, 2);
      // Crossing the assigned period invalidates reuse even inside the freshness window.
      store.state = progress(102);
      await store.refresh(force: false);
      expect(service.reads, 3);
    },
  );

  test(
    'financial mutations during a read request one follow-up and shared callers wait for it',
    () async {
      final auth = SessionAuth()..unlocked = true;
      final first = Completer<MomentumState>();
      final second = Completer<MomentumState>();
      final service =
          SessionMomentumService()
            ..read = (call) => call == 1 ? first.future : second.future;
      final store = MomentumStore(serviceFactory: (_) => service);
      addTearDown(store.dispose);
      addTearDown(auth.dispose);
      final binding = store.bind(auth);
      await Future<void>.delayed(Duration.zero);
      store.financialMutation();
      store.financialMutation();
      var finished = false;
      final joined = store.refresh().then((_) => finished = true);
      first.complete(currentProgress(100));
      await Future<void>.delayed(Duration.zero);
      expect(service.reads, 2);
      expect(finished, isFalse);
      second.complete(currentProgress(150));
      await Future.wait([binding, joined]);
      expect(service.reads, 2);
      expect(store.state?.xp, 150);
    },
  );

  for (final staleFailure in [false, true]) {
    test(
      'authoritative POST avoids a follow-up GET and survives an older ${staleFailure ? 'failure' : 'snapshot'}',
      () async {
        final auth = SessionAuth()..unlocked = true;
        final oldRead = Completer<MomentumState>();
        final service = SessionMomentumService();
        service.read =
            (call) =>
                call == 1 ? Future.value(currentProgress(100)) : oldRead.future;
        service.sendEvent = (_, _) async => currentProgress(150);
        final store = MomentumStore(serviceFactory: (_) => service);
        addTearDown(store.dispose);
        addTearDown(auth.dispose);
        await store.bind(auth);
        final reading = store.refresh();
        await store.event('coachmark_seen');
        expect(store.state?.xp, 150);
        if (staleFailure) {
          oldRead.completeError(StateError('old transport failure'));
        } else {
          oldRead.complete(currentProgress(100));
        }
        await reading;
        expect(store.state?.xp, 150);
        expect(store.offline, isFalse);
        expect(store.error, isNull);
        await store.acceptReview(Future.value(currentProgress(200)));
        expect(store.state?.xp, 200);
        await store.refresh(force: false);
        expect(service.reads, 2);
        final prefs = await SharedPreferences.getInstance();
        expect(
          jsonDecode(prefs.getString('momentum_v1_7')!)['lifetime_xp'],
          200,
        );
      },
    );
  }

  test(
    'seen acknowledgment updates display metadata without another GET or hiding newer progress',
    () async {
      MomentumState withBadge(int xp) => MomentumState({
        ...currentProgress(xp).json,
        'achievements': [
          {
            'key': 'clear_view',
            'completed_at': '2026-09-20T12:00:00Z',
            'seen_at': null,
            'progress': 1,
            'target': 1,
            'xp': 50,
            'available': true,
          },
        ],
      });
      final auth = SessionAuth()..unlocked = true;
      final response = Completer<MomentumState>();
      final service = SessionMomentumService();
      service.read =
          (call) => call == 1 ? Future.value(withBadge(100)) : response.future;
      final store = MomentumStore(serviceFactory: (_) => service);
      addTearDown(store.dispose);
      addTearDown(auth.dispose);
      await store.bind(auth);
      final reading = store.refresh();
      await store.markSeen('clear_view');
      expect(service.seenCalls, 1);
      expect(service.reads, 2);
      expect(store.state!.achievements.single.seen, isTrue);
      expect(store.state?.xp, 100);
      response.complete(withBadge(180));
      await reading;
      expect(store.state?.xp, 180);
      expect(store.state!.achievements.single.seen, isTrue);
      expect(service.reads, 2);
      final prefs = await SharedPreferences.getInstance();
      final cached = MomentumState(
        object(jsonDecode(prefs.getString('momentum_v1_7')!)),
      );
      expect(cached.achievements.single.seen, isTrue);
      expect(cached.xp, 180);
    },
  );

  test(
    'late presentation acknowledgment cannot mark a new account badge seen',
    () async {
      MomentumState badgeFor(int user) => MomentumState({
        ...currentProgress(100).json,
        'user_id': user,
        'achievements': [
          {
            'key': 'clear_view',
            'completed_at': '2026-09-20T12:00:00Z',
            'seen_at': null,
          },
        ],
      });
      final auth = SessionAuth()..unlocked = true;
      final service = _DelayedSeenService();
      service.read = (_) async => badgeFor(auth.userId!);
      final store = MomentumStore(serviceFactory: (_) => service);
      addTearDown(store.dispose);
      addTearDown(auth.dispose);
      await store.bind(auth);
      final marking = store.markSeen('clear_view');
      auth
        ..sessionUser = 8
        ..sessionToken = 'other-session';
      await store.bind(auth);
      service.acknowledgment.complete();
      await marking;
      expect(store.state?.userId, 8);
      expect(store.state!.achievements.single.seen, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('momentum_v1_7'), isNull);
      expect(
        MomentumState(
          object(jsonDecode(prefs.getString('momentum_v1_8')!)),
        ).achievements.single.seen,
        isFalse,
      );
    },
  );

  test(
    'an older POST snapshot cannot replace a newer server generation',
    () async {
      MomentumState snapshot(int xp, int second) => MomentumState({
        ...currentProgress(xp).json,
        'generated_at': '2026-09-25T12:00:0${second}Z',
      });
      final auth = SessionAuth()..unlocked = true;
      final submitted = Completer<MomentumState>();
      final service = SessionMomentumService();
      service.read =
          (call) async => call == 1 ? snapshot(100, 1) : snapshot(200, 3);
      service.sendEvent = (_, _) => submitted.future;
      final store = MomentumStore(serviceFactory: (_) => service);
      addTearDown(store.dispose);
      addTearDown(auth.dispose);
      await store.bind(auth);
      final posting = store.event('coachmark_seen');
      await store.refresh();
      submitted.complete(snapshot(150, 2));
      await posting;
      expect(store.state?.xp, 200);
      expect(service.reads, 2);
    },
  );
}
