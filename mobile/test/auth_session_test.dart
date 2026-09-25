import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/state/auth_store.dart';

String _tokenFor(int user) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'id': user, 'username': 'user$user'}))).replaceAll('=', '')}.signature';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
  tearDown(
    () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
  );

  test(
    'cold start locks a saved biometric session even after an unlock',
    () async {
      final token = _tokenFor(1);
      SharedPreferences.setMockInitialValues({
        'auth_token': token,
        'biometric_enabled': true,
        'auth_locked': false,
        'verified_pro_1': true,
      });
      final auth = AuthStore();
      addTearDown(auth.dispose);
      final loading = auth.load();
      expect(auth.isInitialized, isFalse);
      expect(auth.isRestoring, isTrue);
      await loading;
      expect(auth.token, token);
      expect(auth.userId, 1);
      expect(auth.isPro, isTrue);
      expect(auth.isInitialized, isTrue);
      expect(auth.isRestoring, isFalse);
      expect(auth.loadError, isNull);
      expect(auth.isLocked, isTrue);
      expect(auth.isAuthenticated, isFalse);

      expect(await auth.unlock(expectedToken: token), isTrue);
      await auth.load();
      expect(
        auth.isLocked,
        isFalse,
        reason: 'load is idempotent within a session',
      );
      expect(auth.isAuthenticated, isTrue);

      final reopened = AuthStore();
      addTearDown(reopened.dispose);
      await reopened.load();
      expect(reopened.token, token);
      expect(reopened.isLocked, isTrue);
    },
  );

  test(
    'saved session without biometrics remains available after restart',
    () async {
      final token = _tokenFor(2);
      SharedPreferences.setMockInitialValues({'auth_token': token});
      final auth = AuthStore();
      addTearDown(auth.dispose);
      await auth.load();
      expect(auth.isInitialized, isTrue);
      expect(auth.token, token);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.isLocked, isFalse);
    },
  );

  test('concurrent restore calls share one pending read', () async {
    final preferences = await SharedPreferences.getInstance();
    final started = Completer<void>();
    final pending = Completer<SharedPreferences>();
    var reads = 0;
    final auth = AuthStore(
      preferencesLoader: () {
        reads++;
        started.complete();
        return pending.future;
      },
    );
    addTearDown(auth.dispose);
    final first = auth.load();
    final second = auth.load();
    await started.future;
    expect(reads, 1);
    expect(auth.isRestoring, isTrue);
    expect(auth.isAuthenticated, isFalse);
    pending.complete(preferences);
    await Future.wait([first, second]);
    expect(auth.isInitialized, isTrue);
    expect(auth.hasToken, isFalse);
    expect(auth.loadError, isNull);
  });

  for (final failure in [
    StateError('Storage unavailable'),
    TimeoutException('Storage timed out'),
  ]) {
    test(
      'a ${failure.runtimeType} preserves credentials and can be retried',
      () async {
        final token = _tokenFor(3);
        SharedPreferences.setMockInitialValues({
          'auth_token': token,
          'biometric_enabled': true,
        });
        final preferences = await SharedPreferences.getInstance();
        var fail = true;
        final auth = AuthStore(
          preferencesLoader: () async {
            if (fail) throw failure;
            return preferences;
          },
        );
        addTearDown(auth.dispose);
        await auth.load();
        expect(auth.isInitialized, isFalse);
        expect(auth.isRestoring, isFalse);
        expect(auth.loadError, 'session_restore_failed');
        expect(auth.isAuthenticated, isFalse);
        expect(preferences.getString('auth_token'), token);
        fail = false;
        await auth.load();
        expect(auth.isInitialized, isTrue);
        expect(auth.loadError, isNull);
        expect(auth.token, token);
        expect(auth.isLocked, isTrue);
      },
    );
  }

  test(
    'invalid persisted metadata cannot partially restore or delete a session',
    () async {
      final token = _tokenFor(4);
      SharedPreferences.setMockInitialValues({
        'auth_token': token,
        'biometric_enabled': 'invalid',
      });
      final preferences = await SharedPreferences.getInstance();
      final auth = AuthStore();
      addTearDown(auth.dispose);
      await auth.load();
      expect(auth.token, isNull);
      expect(auth.loadError, isNotNull);
      expect(preferences.getString('auth_token'), token);
      await preferences.setBool('biometric_enabled', true);
      await auth.load();
      expect(auth.token, token);
      expect(auth.isLocked, isTrue);
    },
  );

  for (final signOut in [false, true]) {
    test(
      'a late restore cannot replace a newer ${signOut ? 'logout' : 'login'}',
      () async {
        final oldToken = _tokenFor(5);
        SharedPreferences.setMockInitialValues({
          'auth_token': oldToken,
          'biometric_enabled': true,
        });
        final oldSnapshot = await SharedPreferences.getInstance();
        SharedPreferences.setMockInitialValues({'auth_token': oldToken});
        final currentPreferences = await SharedPreferences.getInstance();
        final started = Completer<void>();
        final delayedRead = Completer<SharedPreferences>();
        var reads = 0;
        final auth = AuthStore(
          preferencesLoader: () {
            if (reads++ == 0) {
              started.complete();
              return delayedRead.future;
            }
            return Future.value(currentPreferences);
          },
        );
        addTearDown(auth.dispose);
        final loading = auth.load();
        await started.future;
        final newToken = signOut ? null : _tokenFor(6);
        if (signOut) {
          await auth.logout(force: true);
        } else {
          await auth.setToken(newToken);
        }
        expect(auth.isInitialized, isTrue);
        expect(auth.isRestoring, isFalse);
        delayedRead.complete(oldSnapshot);
        await loading;
        expect(auth.token, newToken);
        expect(auth.userId, signOut ? null : 6);
        expect(auth.isLocked, isFalse);
        expect(auth.loadError, isNull);
        expect(currentPreferences.getString('auth_token'), newToken);
      },
    );
  }

  test(
    'logout cannot be overwritten by a slower preceding login write',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final started = Completer<void>();
      final delayedWrite = Completer<SharedPreferences>();
      var calls = 0;
      final auth = AuthStore(
        preferencesLoader: () {
          if (calls++ == 0) {
            started.complete();
            return delayedWrite.future;
          }
          return Future.value(preferences);
        },
      );
      addTearDown(auth.dispose);
      final login = auth.setToken(_tokenFor(7));
      expect(auth.isInitialized, isTrue);
      await started.future;
      final logout = auth.logout(force: true);
      expect(auth.hasToken, isFalse);
      delayedWrite.complete(preferences);
      await Future.wait([login, logout]);
      expect(preferences.getString('auth_token'), isNull);
      expect(auth.hasToken, isFalse);
    },
  );

  test(
    'locking preserves credentials and a late challenge cannot unlock another account',
    () async {
      final auth = AuthStore();
      addTearDown(auth.dispose);
      final oldToken = _tokenFor(8);
      final newToken = _tokenFor(9);
      await auth.setToken(oldToken);
      await auth.setBiometricEnabled(true);
      await auth.lock();
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('auth_token'), oldToken);
      expect(preferences.getBool('biometric_enabled'), isTrue);
      await auth.setToken(newToken);
      await auth.lock();
      expect(await auth.unlock(expectedToken: oldToken), isFalse);
      expect(auth.token, newToken);
      expect(auth.isLocked, isTrue);
      expect(preferences.getString('auth_token'), newToken);
      expect(preferences.getBool('auth_locked'), isTrue);
      expect(await auth.unlock(expectedToken: newToken), isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(preferences.getString('auth_token'), newToken);
    },
  );

  test(
    'explicit logout removes credentials and rejects a late unlock',
    () async {
      final token = _tokenFor(10);
      final auth = AuthStore();
      addTearDown(auth.dispose);
      await auth.setToken(token);
      await auth.setBiometricEnabled(true);
      await auth.lock();
      await auth.logout(force: true);
      expect(await auth.unlock(expectedToken: token), isFalse);
      final preferences = await SharedPreferences.getInstance();
      expect(auth.hasToken, isFalse);
      expect(preferences.getString('auth_token'), isNull);
      final reopened = AuthStore();
      addTearDown(reopened.dispose);
      await reopened.load();
      expect(reopened.hasToken, isFalse);
      expect(reopened.isLocked, isFalse);
    },
  );

  test('a rejected old token cannot invalidate the current session', () async {
    final auth = AuthStore();
    addTearDown(auth.dispose);
    final oldToken = _tokenFor(11);
    final currentToken = _tokenFor(12);
    await auth.setToken(oldToken);
    await auth.setToken(currentToken);
    await auth.invalidateToken(oldToken);
    expect(auth.token, currentToken);
    await auth.invalidateToken(currentToken);
    expect(auth.hasToken, isFalse);
    expect(
      (await SharedPreferences.getInstance()).getString('auth_token'),
      isNull,
    );
  });

  test(
    'external activity returns its result and notifies its scope boundaries',
    () async {
      final auth = AuthStore();
      addTearDown(auth.dispose);
      await auth.setToken(_tokenFor(20));
      final states = <bool>[];
      auth.addListener(() => states.add(auth.isExternalActivityActive));
      final result = Completer<String>();
      final activity = auth.runExternalActivity(() => result.future);
      expect(auth.isExternalActivityActive, isTrue);
      expect(states, [true]);
      result.complete('picked-image');
      expect(await activity, 'picked-image');
      expect(auth.isExternalActivityActive, isFalse);
      expect(states, [true, false]);
      expect(auth.token, _tokenFor(20));
    },
  );

  test(
    'native cancellation and errors release their scope without deleting the session',
    () async {
      final auth = AuthStore();
      addTearDown(auth.dispose);
      final token = _tokenFor(21);
      await auth.setToken(token);
      expect(await auth.runExternalActivity<String?>(() async => null), isNull);
      expect(auth.isExternalActivityActive, isFalse);
      await expectLater(
        auth.runExternalActivity<void>(
          () => throw StateError('Native activity failed'),
        ),
        throwsStateError,
      );
      expect(auth.isExternalActivityActive, isFalse);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.token, token);
      expect(
        (await SharedPreferences.getInstance()).getString('auth_token'),
        token,
      );
    },
  );

  test(
    'external activity cannot start before authentication or while locked',
    () async {
      final auth = AuthStore();
      addTearDown(auth.dispose);
      var calls = 0;
      Future<void> action() async {
        calls++;
      }

      await expectLater(auth.runExternalActivity(action), throwsStateError);
      await auth.setToken(_tokenFor(22));
      await auth.lock();
      await expectLater(auth.runExternalActivity(action), throwsStateError);
      expect(calls, 0);
      expect(auth.isExternalActivityActive, isFalse);
      expect(auth.isLocked, isTrue);
    },
  );

  test(
    'overlapping native activities keep protection suspended until both finish',
    () async {
      final auth = AuthStore();
      addTearDown(auth.dispose);
      await auth.setToken(_tokenFor(23));
      final firstResult = Completer<int>();
      final secondResult = Completer<int>();
      final first = auth.runExternalActivity(() => firstResult.future);
      final second = auth.runExternalActivity(() => secondResult.future);
      firstResult.complete(1);
      expect(await first, 1);
      expect(auth.isExternalActivityActive, isTrue);
      secondResult.complete(2);
      expect(await second, 2);
      expect(auth.isExternalActivityActive, isFalse);
    },
  );

  test(
    'a finished old-account activity cannot release a new-account scope or expose its result',
    () async {
      final auth = AuthStore();
      addTearDown(auth.dispose);
      await auth.setToken(_tokenFor(24));
      final oldResult = Completer<String>();
      final oldActivity = auth.runExternalActivity(() => oldResult.future);
      await auth.setToken(_tokenFor(25));
      expect(auth.isExternalActivityActive, isFalse);
      final newResult = Completer<String>();
      final newActivity = auth.runExternalActivity(() => newResult.future);
      final rejected = expectLater(oldActivity, throwsStateError);
      oldResult.complete('old-account-image');
      await rejected;
      expect(auth.userId, 25);
      expect(auth.isExternalActivityActive, isTrue);
      newResult.complete('current-account-image');
      expect(await newActivity, 'current-account-image');
      expect(auth.isExternalActivityActive, isFalse);
    },
  );

  test(
    'an account change triggered by scope completion still rejects the old result',
    () async {
      final auth = AuthStore();
      addTearDown(auth.dispose);
      await auth.setToken(_tokenFor(26));
      final result = Completer<String>();
      final activity = auth.runExternalActivity(() => result.future);
      Future<void>? changedSession;
      void changeOnCompletion() {
        if (!auth.isExternalActivityActive) {
          auth.removeListener(changeOnCompletion);
          changedSession = auth.setToken(_tokenFor(27));
        }
      }

      auth.addListener(changeOnCompletion);
      final rejected = expectLater(activity, throwsStateError);
      result.complete('old-image');
      await rejected;
      await changedSession;
      expect(auth.userId, 27);
      expect(auth.isExternalActivityActive, isFalse);
    },
  );

  test(
    'disposing an external scope cannot exempt a new process from cold-start lock',
    () async {
      final token = _tokenFor(28);
      final auth = AuthStore();
      await auth.setToken(token);
      await auth.setBiometricEnabled(true);
      final pending = Completer<void>();
      final activity = auth.runExternalActivity(() => pending.future);
      expect(auth.isExternalActivityActive, isTrue);
      auth.dispose();
      expect(auth.isExternalActivityActive, isFalse);
      final reopened = AuthStore();
      addTearDown(reopened.dispose);
      await reopened.load();
      expect(reopened.token, token);
      expect(reopened.isLocked, isTrue);
      expect(reopened.isExternalActivityActive, isFalse);
      final rejected = expectLater(activity, throwsStateError);
      pending.complete();
      await rejected;
    },
  );

  test('a native result waits for resume before releasing its scope', () async {
    final auth = AuthStore();
    addTearDown(auth.dispose);
    await auth.setToken(_tokenFor(29));
    final nativeResult = Completer<String>();
    var returned = false;
    final activity = auth.runExternalActivity(() => nativeResult.future).then((
      result,
    ) {
      returned = true;
      return result;
    });
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    nativeResult.complete('picked-image');
    await Future<void>.delayed(Duration.zero);
    expect(returned, isFalse);
    expect(auth.isExternalActivityActive, isTrue);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(await activity, 'picked-image');
    expect(auth.isExternalActivityActive, isFalse);
  });

  test(
    'logout cancels a pending resume wait without returning native data',
    () async {
      final auth = AuthStore();
      addTearDown(auth.dispose);
      await auth.setToken(_tokenFor(30));
      final nativeResult = Completer<String>();
      final activity = auth.runExternalActivity(() => nativeResult.future);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      nativeResult.complete('old-image');
      await Future<void>.delayed(Duration.zero);
      expect(auth.isExternalActivityActive, isTrue);
      final rejected = expectLater(activity, throwsStateError);
      await auth.logout(force: true);
      await rejected;
      expect(auth.isExternalActivityActive, isFalse);
      expect(auth.hasToken, isFalse);
    },
  );
}
