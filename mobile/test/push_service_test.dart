import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/push_service.dart';
import 'package:mobile/state/auth_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PushAuth extends AuthStore {
  String? session = 'session-a';
  int? owner = 7;
  bool unlocked = true;
  @override
  String? get token => session;
  @override
  int? get userId => owner;
  @override
  bool get isInitialized => true;
  @override
  bool get isAuthenticated => unlocked && session != null;
  void change({
    String? token = 'session-a',
    int? user = 7,
    bool active = true,
  }) {
    session = token;
    owner = user;
    unlocked = active;
    notifyListeners();
  }
}

class FakePushAdapter implements PushMessagingAdapter {
  final tokens = StreamController<String>.broadcast(sync: true);
  final foreground = StreamController<RemoteMessage>.broadcast(sync: true);
  final opened = StreamController<RemoteMessage>.broadcast(sync: true);
  int initializations = 0, tokenReads = 0, shown = 0, prompts = 0;
  AuthorizationStatus status = AuthorizationStatus.authorized;
  String? apns = 'synthetic-apns', currentToken = 'device-one';
  Future<String?> Function()? readToken;
  String? launchPayload;
  bool tokenListenerBeforeRead = false;
  @override
  Future<void> initialize(
    void Function(NotificationResponse) onLocalTap,
  ) async {
    initializations++;
  }

  @override
  Stream<String> get tokenRefresh => tokens.stream;
  @override
  Stream<RemoteMessage> get foregroundMessages => foreground.stream;
  @override
  Stream<RemoteMessage> get openedMessages => opened.stream;
  @override
  Future<AuthorizationStatus> permission({bool requestIfNeeded = false}) async {
    if (requestIfNeeded) prompts++;
    return status;
  }

  @override
  Future<String?> apnsToken() async => apns;
  @override
  Future<String?> token() {
    tokenReads++;
    tokenListenerBeforeRead = tokens.hasListener;
    return readToken?.call() ?? Future.value(currentToken);
  }

  @override
  Future<RemoteMessage?> initialMessage() async => null;
  @override
  Future<String?> initialLocalPayload() async => launchPayload;
  @override
  Future<void> showForeground(RemoteMessage message) async {
    shown++;
  }

  Future<void> close() async {
    await tokens.close();
    await foreground.close();
    await opened.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Android first permission prompt handles the SDK denied-before-prompt state',
    () {
      expect(
        shouldRequestPushPermission(
          TargetPlatform.android,
          AuthorizationStatus.denied,
          previouslyRequested: false,
        ),
        isTrue,
      );
      expect(
        shouldRequestPushPermission(
          TargetPlatform.android,
          AuthorizationStatus.denied,
          previouslyRequested: true,
        ),
        isFalse,
      );
      expect(
        shouldRequestPushPermission(
          TargetPlatform.iOS,
          AuthorizationStatus.denied,
          previouslyRequested: false,
        ),
        isFalse,
      );
      expect(
        shouldRequestPushPermission(
          TargetPlatform.iOS,
          AuthorizationStatus.notDetermined,
          previouslyRequested: false,
        ),
        isTrue,
      );
    },
  );

  test(
    'late APNs token recovers on foreground with the refresh listener already installed',
    () async {
      final auth = PushAuth();
      final adapter = FakePushAdapter()..apns = null;
      final registered = <String>[];
      final service = PushService.forTesting(
        adapter: adapter,
        auth: () => auth,
        platform: TargetPlatform.iOS,
        register: (_, token, _, _, _) async => registered.add(token),
      );
      addTearDown(() async {
        await service.dispose();
        await adapter.close();
        auth.dispose();
      });
      await service.init();
      expect(adapter.tokens.hasListener, isTrue);
      expect(adapter.tokenReads, 0);
      expect(registered, isEmpty);
      expect(service.registrationIssue, 'apns_pending');
      adapter.apns = 'synthetic-apns';
      await service.syncTokenWithBackend();
      expect(registered, ['device-one']);
      expect(adapter.tokenListenerBeforeRead, isTrue);
      expect(service.registrationIssue, isNull);
    },
  );

  test(
    'a transient token failure is recoverable through the live token stream',
    () async {
      final auth = PushAuth();
      final adapter = FakePushAdapter();
      adapter.readToken = () async {
        if (adapter.tokenReads == 1) throw StateError('synthetic SDK failure');
        return 'device-two';
      };
      final registered = <String>[];
      final service = PushService.forTesting(
        adapter: adapter,
        auth: () => auth,
        register: (_, token, _, _, _) async => registered.add(token),
      );
      addTearDown(() async {
        await service.dispose();
        await adapter.close();
        auth.dispose();
      });
      await service.init();
      expect(adapter.tokens.hasListener, isTrue);
      expect(registered, isEmpty);
      adapter.tokens.add('device-two');
      await service.syncTokenWithBackend();
      expect(registered, ['device-two']);
      expect(service.registrationIssue, isNull);
    },
  );

  test(
    'concurrent initialization and foreground sync deduplicate backend registration',
    () async {
      final auth = PushAuth();
      final adapter = FakePushAdapter();
      final registered = <String>[];
      final service = PushService.forTesting(
        adapter: adapter,
        auth: () => auth,
        register: (_, token, _, _, _) async => registered.add(token),
      );
      addTearDown(() async {
        await service.dispose();
        await adapter.close();
        auth.dispose();
      });
      await Future.wait([service.init(), service.init()]);
      await Future.wait([
        service.syncTokenWithBackend(),
        service.syncTokenWithBackend(),
      ]);
      expect(adapter.initializations, 1);
      expect(adapter.prompts, 1);
      expect(registered, ['device-one']);
    },
  );

  test(
    'denied permission does not register, returning from settings retries current SDK token',
    () async {
      final auth = PushAuth();
      final adapter = FakePushAdapter()..status = AuthorizationStatus.denied;
      final registered = <String>[];
      final service = PushService.forTesting(
        adapter: adapter,
        auth: () => auth,
        register: (_, token, _, _, _) async => registered.add(token),
      );
      addTearDown(() async {
        await service.dispose();
        await adapter.close();
        auth.dispose();
      });
      await service.init();
      expect(registered, isEmpty);
      expect(adapter.tokenReads, 0);
      adapter.status = AuthorizationStatus.authorized;
      await service.syncTokenWithBackend();
      expect(registered, ['device-one']);
      expect(adapter.prompts, 1);
    },
  );

  test(
    'biometric lock parks token rotation without any backend calls, unlock registers the latest token',
    () async {
      final auth = PushAuth()..unlocked = false;
      final adapter = FakePushAdapter();
      final requests = <String>[];
      final service = PushService.forTesting(
        adapter: adapter,
        auth: () => auth,
        register:
            (session, token, _, _, _) async =>
                requests.add('register:$session:$token'),
        unregister:
            (session, token) async => requests.add('unlink:$session:$token'),
      );
      addTearDown(() async {
        await service.dispose();
        await adapter.close();
        auth.dispose();
      });
      await service.init();
      adapter.currentToken = 'device-two';
      adapter.tokens.add('device-two');
      await service.syncTokenWithBackend();
      expect(requests, isEmpty);
      auth.change();
      await service.syncTokenWithBackend();
      expect(requests, ['register:session-a:device-two']);
      auth.change(active: false);
      adapter.currentToken = 'device-three';
      adapter.tokens.add('device-three');
      await service.syncTokenWithBackend();
      expect(requests, hasLength(1));
      auth.change();
      await service.syncTokenWithBackend();
      expect(requests, contains('register:session-a:device-three'));
      expect(requests, contains('unlink:session-a:device-two'));
    },
  );

  test(
    'session change during native context read cannot register against the outgoing account',
    () async {
      final auth = PushAuth();
      final adapter = FakePushAdapter();
      final contextReady = Completer<void>();
      var contextCalls = 0;
      final registered = <String>[];
      final service = PushService.forTesting(
        adapter: adapter,
        auth: () => auth,
        refreshContext:
            () => ++contextCalls == 1 ? contextReady.future : Future.value(),
        register: (session, _, _, _, _) async => registered.add(session),
      );
      addTearDown(() async {
        await service.dispose();
        await adapter.close();
        auth.dispose();
      });
      final init = service.init();
      await Future<void>.delayed(Duration.zero);
      auth.change(token: 'session-b', user: 8);
      contextReady.complete();
      await init;
      await service.syncTokenWithBackend();
      expect(registered, ['session-b']);
    },
  );

  test(
    'account change serializes outgoing unlink after an in-flight registration and before the new owner',
    () async {
      final auth = PushAuth();
      final adapter = FakePushAdapter();
      final registered = Completer<void>();
      final actions = <String>[];
      final service = PushService.forTesting(
        adapter: adapter,
        auth: () => auth,
        register: (session, _, _, _, _) async {
          actions.add('register:$session');
          if (session == 'session-a') await registered.future;
        },
        unregister: (session, _) async => actions.add('unlink:$session'),
      );
      addTearDown(() async {
        await service.dispose();
        await adapter.close();
        auth.dispose();
      });
      final init = service.init();
      await Future<void>.delayed(Duration.zero);
      expect(actions, ['register:session-a']);
      auth.change(token: 'session-b', user: 8);
      registered.complete();
      await init;
      await service.syncTokenWithBackend();
      expect(actions, [
        'register:session-a',
        'unlink:session-a',
        'register:session-b',
      ]);
      auth.change(token: null, user: null, active: false);
      await service.syncTokenWithBackend();
      expect(actions.last, 'unlink:session-b');
    },
  );

  test(
    'same-account session rotation preserves association and re-registers with current credentials',
    () async {
      final auth = PushAuth();
      final adapter = FakePushAdapter();
      final actions = <String>[];
      final service = PushService.forTesting(
        adapter: adapter,
        auth: () => auth,
        register:
            (session, _, _, _, _) async => actions.add('register:$session'),
        unregister: (session, _) async => actions.add('unlink:$session'),
      );
      addTearDown(() async {
        await service.dispose();
        await adapter.close();
        auth.dispose();
      });
      await service.init();
      auth.change(token: 'session-a-new');
      await service.syncTokenWithBackend();
      expect(actions, ['register:session-a', 'register:session-a-new']);
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    test(
      'foreground presentation avoids duplicate local iOS alerts on $platform',
      () async {
        final auth = PushAuth();
        final adapter = FakePushAdapter();
        final service = PushService.forTesting(
          adapter: adapter,
          auth: () => auth,
          platform: platform,
          register: (_, _, _, _, _) async {},
        );
        addTearDown(() async {
          await service.dispose();
          await adapter.close();
          auth.dispose();
        });
        await service.init();
        adapter.foreground.add(
          const RemoteMessage(
            notification: RemoteNotification(title: 'Synthetic reminder'),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(adapter.shown, platform == TargetPlatform.android ? 1 : 0);
      },
    );
  }

  test(
    'a local foreground notification tap survives a cold app launch',
    () async {
      final auth = PushAuth()..unlocked = false;
      final adapter =
          FakePushAdapter()
            ..launchPayload =
                '{"type":"momentum_comeback","route":"/momentum"}';
      final service = PushService.forTesting(
        adapter: adapter,
        auth: () => auth,
        register: (_, _, _, _, _) async {},
      );
      addTearDown(() async {
        await service.dispose();
        await adapter.close();
        auth.dispose();
      });
      await service.init();
      expect(service.consumeInitialAction()?.targetType, 'momentum');
      expect(service.consumeInitialAction(), isNull);
    },
  );
  testWidgets(
    'transient backend registration retries automatically and stops after success',
    (tester) async {
      final auth = PushAuth();
      final adapter = FakePushAdapter();
      var attempts = 0;
      final service = PushService.forTesting(
        adapter: adapter,
        auth: () => auth,
        register: (_, _, _, _, _) async {
          if (++attempts == 1) throw StateError('synthetic offline');
        },
      );
      try {
        await service.init();

        expect(attempts, 1);
        await tester.pump(const Duration(seconds: 2));
        expect(attempts, 2);
        expect(service.registrationIssue, isNull);
        await tester.pump(const Duration(minutes: 1));
        expect(attempts, 2);
      } finally {
        await tester.runAsync(() async {
          await service.dispose();
          await adapter.close();
          auth.dispose();
        });
      }
    },
  );

  testWidgets(
    'logout cleanup retries are bounded and never register an unauthenticated session',
    (tester) async {
      final auth = PushAuth();
      final adapter = FakePushAdapter();
      var registrations = 0, unlinks = 0;
      final service = PushService.forTesting(
        adapter: adapter,
        auth: () => auth,
        register: (_, _, _, _, _) async {
          registrations++;
        },
        unregister: (_, _) async {
          unlinks++;
          throw StateError('synthetic offline');
        },
      );
      try {
        await service.init();
        auth.change(token: null, user: null, active: false);
        await service.syncTokenWithBackend();
        expect(registrations, 1);
        // Two concurrent logout sync callers share the work; only one retry timer exists.
        final initialUnlinks = unlinks;
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(seconds: 5));
        await tester.pump(const Duration(seconds: 15));
        expect(unlinks, initialUnlinks + 3);
        await tester.pump(const Duration(minutes: 1));
        expect(unlinks, initialUnlinks + 3);
        expect(registrations, 1);
      } finally {
        await tester.runAsync(() async {
          await service.dispose();
          await adapter.close();
          auth.dispose();
        });
      }
    },
  );
}
