import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/lang_store.dart';
import 'package:mobile/liquid_glass/liquid_glass.dart';
import 'package:mobile/main.dart';
import 'package:mobile/momentum/store.dart';
import 'package:mobile/screens/lock_screen.dart';
import 'package:mobile/screens/login_screen.dart';
import 'package:mobile/screens/password_recovery_screen.dart';
import 'package:mobile/services/analytics_service.dart';
import 'package:mobile/services/session_lifecycle.dart';
import 'package:mobile/state/auth_store.dart';
import 'package:mobile/state/refresh_bus.dart';
import 'package:mobile/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _userId = 71041;
final _token =
    'header.${base64Url.encode(utf8.encode(jsonEncode({'id': _userId, 'exp': 4102444800}))).replaceAll('=', '')}.signature';
const _authenticatedRoot = Key('authenticated-root');
const _protectedSettings = Key('protected-settings');

/// Keep protected content deliberately small while exercising the real session
/// observer, navigator, AppGate, LockScreen, stores, and HTTP clients.
class _SessionHarness extends StatelessWidget {
  const _SessionHarness({required this.auth});
  final AuthStore auth;

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthStore>.value(value: auth),
      ChangeNotifierProvider(create: (_) => LangStore()),
      ChangeNotifierProvider(create: (_) => RefreshBus()),
      ChangeNotifierProvider(create: (_) => MomentumStore()),
    ],
    child: SessionLifecycle(
      child: MaterialApp(
        navigatorKey: sessionNavigatorKey,
        navigatorObservers: [sessionRouteObserver],
        theme: AppTheme.light(),
        home: Consumer<AuthStore>(
          builder:
              (_, auth, _) =>
                  auth.isAuthenticated
                      ? const Scaffold(
                        body: Text(
                          'Authenticated root',
                          key: _authenticatedRoot,
                        ),
                      )
                      : const AppGate(),
        ),
      ),
    ),
  );
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const biometricChannel = MethodChannel('plugins.flutter.io/local_auth');
  const clientContextChannel = MethodChannel('com.finsight/client_context');
  var biometricResult = false;
  var biometricChallenges = 0;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sessionRouteObserver.current = null;
    binding.platformDispatcher.defaultRouteNameTestValue = '/';
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    biometricResult = false;
    biometricChallenges = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(biometricChannel, (
      call,
    ) async {
      switch (call.method) {
        case 'isDeviceSupported':
          return true;
        case 'getAvailableBiometrics':
          return ['fingerprint'];
        case 'authenticate':
          biometricChallenges++;
          expect((call.arguments as Map)['biometricOnly'], isTrue);
          return biometricResult;
        case 'stopAuthentication':
          return true;
        default:
          throw MissingPluginException(call.method);
      }
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      clientContextChannel,
      (_) async => {'timezone': 'UTC'},
    );
  });

  tearDown(() {
    binding.platformDispatcher.clearDefaultRouteNameTestValue();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      biometricChannel,
      null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      clientContextChannel,
      null,
    );
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  Future<void> withMockHttp(
    WidgetTester tester,
    Future<void> Function(List<http.Request> requests) body,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <http.Request>[];
    await http.runWithClient(
      () async {
        try {
          await body(requests);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          // Analytics is a process singleton; clear its timers and identity between
          // tests without involving a backend or leaving a disposed AuthStore.
          final emptyAuth = AuthStore();
          await AnalyticsService.instance.bind(emptyAuth);
          emptyAuth.dispose();
          AuthStore.instance = null;
          await tester.pump();
        }
      },
      () => MockClient((request) async {
        requests.add(request);
        final payload = switch (request.url.path) {
          '/api/engagement/me' => {'enabled': false, 'user_id': _userId},
          '/api/analytics/preferences' => {'enabled': false, 'available': true},
          '/api/analytics/events' => {'accepted': 0},
          _ => <Object>[],
        };
        return http.Response(jsonEncode(payload), 200);
      }),
    );
  }

  Future<AuthStore> restoredAuth({required bool locked}) async {
    SharedPreferences.setMockInitialValues({
      'auth_token': _token,
      'biometric_enabled': locked,
      'auth_locked': false,
    });
    final auth = AuthStore();
    await auth.load();
    if (!locked) await auth.setBiometricEnabled(true);
    return auth;
  }

  Future<void> pushSettings(WidgetTester tester) async {
    sessionNavigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/settings'),
        builder:
            (_) => const Scaffold(
              body: Text('Protected settings', key: _protectedSettings),
            ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_protectedSettings), findsOneWidget);
    expect(sessionNavigatorKey.currentState!.canPop(), isTrue);
  }

  testWidgets('AppGate waits for storage before choosing any session screen', (
    tester,
  ) async {
    await withMockHttp(tester, (requests) async {
      final auth = AuthStore();
      addTearDown(auth.dispose);
      await tester.pumpWidget(_SessionHarness(auth: auth));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(LockScreen), findsNothing);
      expect(find.byType(HomeShell, skipOffstage: false), findsNothing);
      expect(requests, isEmpty);

      await auth.load();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(requests, isEmpty);
    });
  });

  testWidgets(
    'session storage failure offers retry without discarding a token',
    (tester) async {
      await withMockHttp(tester, (requests) async {
        SharedPreferences.setMockInitialValues({
          'auth_token': _token,
          'biometric_enabled': true,
        });
        final preferences = await SharedPreferences.getInstance();
        var attempts = 0;
        final auth = AuthStore(
          preferencesLoader: () async {
            if (++attempts == 1) {
              throw StateError('Synthetic storage read failure');
            }
            return preferences;
          },
        );
        addTearDown(auth.dispose);
        await auth.load();
        await tester.pumpWidget(_SessionHarness(auth: auth));
        await tester.pumpAndSettle();
        expect(find.text('Retry'), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.byType(HomeShell, skipOffstage: false), findsNothing);
        expect(preferences.getString('auth_token'), _token);
        expect(requests, isEmpty);

        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(find.byType(LockScreen), findsOneWidget);
        expect(auth.token, _token);
        expect(auth.isLocked, isTrue);
        expect(preferences.getString('auth_token'), _token);
        expect(requests, isEmpty);
      });
    },
  );

  for (final persistedLock in [false, true]) {
    testWidgets(
      'cold biometric session stays private with auth_locked=$persistedLock',
      (tester) async {
        await withMockHttp(tester, (requests) async {
          SharedPreferences.setMockInitialValues({
            'auth_token': _token,
            'biometric_enabled': true,
            'auth_locked': persistedLock,
          });
          await tester.pumpWidget(const FinancialBoardRoot());
          await tester.pumpAndSettle();

          expect(find.byType(LockScreen), findsOneWidget);
          expect(find.byType(HomeShell, skipOffstage: false), findsNothing);
          expect(find.byType(LoginScreen, skipOffstage: false), findsNothing);
          final auth =
              tester.element(find.byType(LockScreen)).read<AuthStore>();
          expect(auth.token, _token);
          expect(auth.isAuthenticated, isFalse);
          expect(auth.isLocked, isTrue);
          expect(biometricChallenges, 0);
          await tester.pump(const Duration(minutes: 2));
          expect(requests, isEmpty);
          final preferences = await SharedPreferences.getInstance();
          expect(preferences.getString('auth_token'), _token);
        });
      },
    );
  }

  for (final state in [
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.detached,
  ]) {
    testWidgets(
      '$state locks protected navigation and resume preserves the session',
      (tester) async {
        await withMockHttp(tester, (requests) async {
          final auth = await restoredAuth(locked: false);
          addTearDown(auth.dispose);
          await tester.pumpWidget(_SessionHarness(auth: auth));
          await tester.pumpAndSettle();
          expect(find.byKey(_authenticatedRoot), findsOneWidget);
          await pushSettings(tester);
          requests.clear();

          binding.handleAppLifecycleStateChanged(state);
          await tester.pump();
          await tester.pump(const Duration(minutes: 2));
          binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await tester.pumpAndSettle();

          expect(auth.token, _token);
          expect(auth.isLocked, isTrue);
          expect(auth.isAuthenticated, isFalse);
          expect(find.byType(LockScreen), findsOneWidget);
          expect(find.byType(HomeShell, skipOffstage: false), findsNothing);
          expect(
            find.byKey(_protectedSettings, skipOffstage: false),
            findsNothing,
          );
          expect(sessionNavigatorKey.currentState!.canPop(), isFalse);
          expect(requests, isEmpty);
          expect(biometricChallenges, 0);
          final preferences = await SharedPreferences.getInstance();
          expect(preferences.getString('auth_token'), _token);
          expect(preferences.getBool('auth_locked'), isTrue);
        });
      },
    );
  }

  testWidgets('manual lock removes an already open protected route', (
    tester,
  ) async {
    await withMockHttp(tester, (requests) async {
      final auth = await restoredAuth(locked: false);
      addTearDown(auth.dispose);
      await tester.pumpWidget(_SessionHarness(auth: auth));
      await tester.pumpAndSettle();
      await pushSettings(tester);
      requests.clear();

      await auth.lock();
      await tester.pumpAndSettle();
      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.byKey(_protectedSettings, skipOffstage: false), findsNothing);
      expect(sessionNavigatorKey.currentState!.canPop(), isFalse);
      expect(auth.token, _token);
      expect(requests, isEmpty);
    });
  });

  testWidgets('locking preserves the public password recovery route', (
    tester,
  ) async {
    await withMockHttp(tester, (requests) async {
      final auth = await restoredAuth(locked: false);
      addTearDown(auth.dispose);
      await tester.pumpWidget(_SessionHarness(auth: auth));
      await tester.pumpAndSettle();
      sessionNavigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/reset-password'),
          builder: (_) => const ResetPasswordScreen(token: null),
        ),
      );
      await tester.pumpAndSettle();
      requests.clear();

      await auth.lock();
      await tester.pumpAndSettle();
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.byType(LockScreen, skipOffstage: false), findsOneWidget);
      expect(find.byType(HomeShell, skipOffstage: false), findsNothing);
      expect(sessionRouteObserver.current, '/reset-password');
      expect(sessionNavigatorKey.currentState!.canPop(), isTrue);
      expect(requests, isEmpty);
    });
  });

  for (final recoveryBeforeLock in [true, false]) {
    testWidgets(
      'recovery ${recoveryBeforeLock ? 'open before' : 'received after'} lock '
      'cannot reveal the previous protected route',
      (tester) async {
        await withMockHttp(tester, (requests) async {
          final auth = await restoredAuth(locked: false);
          addTearDown(auth.dispose);
          await tester.pumpWidget(_SessionHarness(auth: auth));
          await tester.pumpAndSettle();
          await pushSettings(tester);
          requests.clear();

          if (!recoveryBeforeLock) {
            // Queue cleanup, then deliver the public route before the next frame.
            await auth.lock();
          }
          final recoveryToken = List.filled(43, 'r').join();
          sessionNavigatorKey.currentState!.push<void>(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/reset-password'),
              builder: (_) => ResetPasswordScreen(token: recoveryToken),
            ),
          );
          Object? recoveryState;
          if (recoveryBeforeLock) {
            await tester.pumpAndSettle();
            recoveryState = tester.state(find.byType(ResetPasswordScreen));
            await auth.lock();
          }
          await tester.pumpAndSettle();

          expect(find.byType(ResetPasswordScreen), findsOneWidget);
          expect(
            tester
                .widget<ResetPasswordScreen>(find.byType(ResetPasswordScreen))
                .token,
            recoveryToken,
          );
          if (recoveryState != null) {
            expect(
              tester.state(find.byType(ResetPasswordScreen)),
              same(recoveryState),
            );
          }
          expect(
            find.byKey(_protectedSettings, skipOffstage: false),
            findsNothing,
          );
          expect(find.byType(LockScreen, skipOffstage: false), findsOneWidget);
          expect(sessionRouteObserver.current, '/reset-password');
          expect(sessionNavigatorKey.currentState!.canPop(), isTrue);

          sessionNavigatorKey.currentState!.pop();
          await tester.pumpAndSettle();
          expect(find.byType(LockScreen), findsOneWidget);
          expect(find.byType(ResetPasswordScreen), findsNothing);
          expect(
            find.byKey(_protectedSettings, skipOffstage: false),
            findsNothing,
          );
          expect(sessionNavigatorKey.currentState!.canPop(), isFalse);
          expect(auth.token, _token);
          expect(auth.isLocked, isTrue);
          expect(requests, isEmpty);
        });
      },
    );
  }

  testWidgets(
    'native handoff survives pause, then the next ordinary pause locks',
    (tester) async {
      await withMockHttp(tester, (requests) async {
        final auth = await restoredAuth(locked: false);
        addTearDown(auth.dispose);
        await tester.pumpWidget(_SessionHarness(auth: auth));
        await tester.pumpAndSettle();
        await pushSettings(tester);
        requests.clear();

        final pending = Completer<void>();
        final activity = auth.runExternalActivity<void>(() => pending.future);
        expect(auth.isExternalActivityActive, isTrue);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        await tester.pump(const Duration(minutes: 2));
        expect(auth.isLocked, isFalse);
        expect(find.byKey(_protectedSettings), findsOneWidget);
        expect(requests, isEmpty);

        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pumpAndSettle();
        pending.complete();
        await activity;
        await tester.pumpAndSettle();
        expect(auth.isExternalActivityActive, isFalse);
        expect(auth.isAuthenticated, isTrue);
        expect(auth.token, _token);
        expect(find.byKey(_protectedSettings), findsOneWidget);
        requests.clear();

        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pumpAndSettle();
        expect(auth.isLocked, isTrue);
        expect(find.byType(LockScreen), findsOneWidget);
        expect(
          find.byKey(_protectedSettings, skipOffstage: false),
          findsNothing,
        );
        expect(auth.token, _token);
        expect(requests, isEmpty);
      });
    },
  );

  testWidgets(
    'a native result received before resume stays pending until foreground',
    (tester) async {
      await withMockHttp(tester, (requests) async {
        final auth = await restoredAuth(locked: false);
        addTearDown(auth.dispose);
        await tester.pumpWidget(_SessionHarness(auth: auth));
        await tester.pumpAndSettle();
        await pushSettings(tester);
        requests.clear();

        final pending = Completer<void>();
        var returned = false;
        final activity = auth
            .runExternalActivity<void>(() => pending.future)
            .then((_) {
              returned = true;
            });
        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        expect(auth.isLocked, isFalse);

        pending.complete();
        await tester.pump();
        expect(returned, isFalse);
        expect(auth.isExternalActivityActive, isTrue);
        expect(auth.isLocked, isFalse);
        expect(requests, isEmpty);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        await activity;
        await tester.pumpAndSettle();
        expect(returned, isTrue);
        expect(auth.isExternalActivityActive, isFalse);
        expect(auth.isAuthenticated, isTrue);
        expect(find.byType(LockScreen), findsNothing);
        expect(find.byKey(_protectedSettings), findsOneWidget);
        expect(auth.token, _token);
      });
    },
  );

  testWidgets('biometric cancellation keeps the token and success unlocks it', (
    tester,
  ) async {
    await withMockHttp(tester, (requests) async {
      final auth = await restoredAuth(locked: true);
      addTearDown(auth.dispose);
      await tester.pumpWidget(_SessionHarness(auth: auth));
      await tester.pumpAndSettle();
      final unlockButton = find.byWidgetPredicate(
        (widget) => widget is LGButton && widget.icon == Icons.fingerprint,
      );
      expect(find.byType(LockScreen), findsOneWidget);
      expect(unlockButton, findsOneWidget);
      expect(requests, isEmpty);

      await tester.tap(unlockButton);
      await tester.pumpAndSettle();
      expect(biometricChallenges, 1);
      expect(auth.token, _token);
      expect(auth.isLocked, isTrue);
      expect(find.byType(LockScreen), findsOneWidget);
      expect(requests, isEmpty);

      biometricResult = true;
      await tester.tap(unlockButton);
      await tester.pumpAndSettle();
      expect(biometricChallenges, 2);
      expect(auth.token, _token);
      expect(auth.isAuthenticated, isTrue);
      expect(find.byType(LockScreen), findsNothing);
      expect(find.byKey(_authenticatedRoot), findsOneWidget);
      expect(requests.any((r) => r.url.path == '/api/engagement/me'), isTrue);
      for (final request in requests) {
        expect(request.headers['authorization'], 'Bearer $_token');
      }
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('auth_token'), _token);
      expect(preferences.getBool('auth_locked') ?? false, isFalse);
    });
  });
}
