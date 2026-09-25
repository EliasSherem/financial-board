import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/lang_store.dart';
import 'package:mobile/momentum/models.dart';
import 'package:mobile/momentum/service.dart';
import 'package:mobile/momentum/store.dart';
import 'package:mobile/momentum/widgets.dart';
import 'package:mobile/momentum/screens.dart';
import 'package:mobile/liquid_glass/liquid_glass.dart';
import 'package:mobile/screens/password_recovery_screen.dart';
import 'package:mobile/services/client_context.dart';
import 'package:mobile/state/auth_store.dart';
import 'package:mobile/state/refresh_bus.dart';
import 'package:mobile/screens/dashboard_screen.dart';
import 'package:mobile/theme.dart';

String tokenFor(int id) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'id': id}))).replaceAll('=', '')}.signature';
Json progressFor(int user, {int xp = 90}) => {
  'enabled': true,
  'user_id': user,
  'lifetime_xp': xp,
  'rhythm': 2,
  'level': {
    'key': 'explorer',
    'title': {'en': 'Explorer', 'es': 'Explorador'},
    'minimum_xp': 0,
    'next_xp': 150,
  },
  'week': {
    'assigned': true,
    'completed': 1,
    'total': 3,
    'cap': 100,
    'repeatable_xp': 80,
    'bonus_xp': 0,
  },
  'missions': [
    {
      'key': 'weekly_summary',
      'scope': 'weekly',
      'slot': 'review',
      'status': 'active',
      'review': true,
      'title': {'en': 'Review your week', 'es': 'Revisa tu semana'},
      'requirement': {
        'en': 'Review current data',
        'es': 'Revisa datos actuales',
      },
      'progress': 0,
      'target': 1,
      'nominal_xp': 40,
      'granted_xp': 0,
      'deeplink': '/momentum',
    },
  ],
  'achievements': [],
};

class FakeMomentumService extends MomentumService {
  FakeMomentumService(super.token, this.fetch);
  final Future<MomentumState> Function() fetch;
  Json? snapshot;
  Future<MomentumState> Function(Json)? submit;
  @override
  Future<Json> review(String kind) async => snapshot!;
  @override
  Future<MomentumState> event(Json payload) => submit!(payload);
  @override
  Future<MomentumState> me() => fetch();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('reset links require own scheme or exact app route and safe tokens', () {
    final token = List.filled(43, 'a').join();
    expect(
      recoveryTokenFromUri(
        Uri.parse('financialboard://reset-password#token=$token'),
      ),
      token,
    );
    expect(
      recoveryTokenFromUri(Uri.parse('/reset-password#token=$token')),
      token,
    );
    expect(
      recoveryTokenFromUri(
        Uri.parse('https://evil.test/reset-password#token=$token'),
      ),
      isNull,
    );
    expect(
      recoveryTokenFromUri(Uri.parse('financialboard://other#token=$token')),
      isNull,
    );
    expect(
      recoveryTokenFromUri(Uri.parse('/reset-password#token=short')),
      isNull,
    );
    expect(
      recoveryTokenFromUri(Uri.parse('/reset-password#token=%FF')),
      isNull,
    );
  });
  test('client identifiers are unique UUID v4 without user data', () {
    final ids = List.generate(100, (_) => clientEventId());
    expect(ids.toSet(), hasLength(100));
    for (final id in ids) {
      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    }
  });
  test(
    'server progress is authoritative and activation shows at most three active steps',
    () {
      final state = MomentumState({
        ...progressFor(7),
        'lifetime_xp': 200,
        'missions': List.generate(
          6,
          (i) => {
            'key': 'activation_$i',
            'scope': 'activation',
            'status': i == 0 ? 'completed' : 'active',
            'nominal_xp': 50,
            'granted_xp': 0,
          },
        ),
      });
      expect(state.levelProgress, 1);
      expect(state.activation.map((m) => m.key), [
        'activation_1',
        'activation_2',
        'activation_3',
      ]);
      expect(state.activation.first.grantedXp, 0);
      expect(MomentumState({'enabled': false, 'user_id': 7}).missions, isEmpty);
      expect(MomentumState(progressFor(7)).requiredWeek.single.review, isTrue);
    },
  );
  test('offline cache is scoped to account and cleared on logout', () async {
    final auth = AuthStore();
    await auth.setToken(tokenFor(7));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('momentum_v1_7', jsonEncode(progressFor(7)));
    final store = MomentumStore(
      serviceFactory:
          (token) => FakeMomentumService(
            token,
            () async => throw StateError('offline'),
          ),
    );
    await store.bind(auth);
    expect(store.state?.userId, 7);
    expect(store.offline, isTrue);
    await auth.logout(force: true);
    await store.bind(auth);
    expect(store.state, isNull);
    expect(prefs.getString('momentum_v1_7'), isNull);
    store.dispose();
    auth.dispose();
  });
  test(
    'late old-account response cannot restore progress in a new account',
    () async {
      final auth = AuthStore();
      final first = Completer<MomentumState>();
      await auth.setToken(tokenFor(7));
      final store = MomentumStore(
        serviceFactory:
            (token) => FakeMomentumService(
              token,
              () =>
                  token == tokenFor(7)
                      ? first.future
                      : Future.value(MomentumState(progressFor(8, xp: 10))),
            ),
      );
      final oldBind = store.bind(auth);
      await Future<void>.delayed(Duration.zero);
      await auth.setToken(tokenFor(8));
      await store.bind(auth);
      first.complete(MomentumState(progressFor(7, xp: 999)));
      await oldBind;
      expect(store.state?.userId, 8);
      expect(store.state?.xp, 10);
      store.dispose();
      auth.dispose();
    },
  );
  test('a mutation during refresh schedules a fresh server read', () async {
    final auth = AuthStore();
    await auth.setToken(tokenFor(7));
    final first = Completer<MomentumState>();
    int calls = 0;
    final store = MomentumStore(
      serviceFactory:
          (token) => FakeMomentumService(token, () {
            calls++;
            return calls == 1
                ? first.future
                : Future.value(MomentumState(progressFor(7, xp: 111)));
          }),
    );
    final loading = store.bind(auth);
    await Future<void>.delayed(Duration.zero);
    store.financialMutation();
    first.complete(MomentumState(progressFor(7, xp: 90)));
    await loading;
    await Future<void>.delayed(Duration.zero);
    expect(calls, 2);
    expect(store.state?.xp, 111);
    store.dispose();
    auth.dispose();
  });

  testWidgets('financial network errors preserve login and cached Momentum', (
    tester,
  ) async {
    final auth = AuthStore();
    await auth.setToken(tokenFor(7));
    final language = LangStore();
    final refresh = RefreshBus();
    final store = MomentumStore()..state = MomentumState(progressFor(7));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthStore>.value(value: auth),
          ChangeNotifierProvider<LangStore>.value(value: language),
          ChangeNotifierProvider<RefreshBus>.value(value: refresh),
          ChangeNotifierProvider<MomentumStore>.value(value: store),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: DashboardScreen()),
        ),
      ),
    );
    // Flutter's HTTP override returns 400, exercising the real error branch.
    await tester.pumpAndSettle();
    expect(auth.userId, 7);
    expect(auth.token, tokenFor(7));
    expect(find.byType(MomentumHomeCard), findsOneWidget);
    expect(find.text('Unable to load your finances'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
    refresh.dispose();
    auth.dispose();
    language.dispose();
  });

  testWidgets(
    'disabled Momentum cache exposes failed refresh and retry without invented progress',
    (tester) async {
      final auth = AuthStore();
      await auth.setToken(tokenFor(7));
      final language = LangStore();
      final failedResponse = Completer<MomentumState>();
      final enabledResponse = Completer<MomentumState>();
      var reads = 0;
      final store = MomentumStore(
        serviceFactory:
            (token) => FakeMomentumService(token, () {
              reads++;
              return switch (reads) {
                2 => failedResponse.future,
                3 => enabledResponse.future,
                _ => Future.value(
                  MomentumState({'enabled': false, 'user_id': 7}),
                ),
              };
            }),
      );
      await store.bind(auth);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MomentumStore>.value(value: store),
            ChangeNotifierProvider<LangStore>.value(value: language),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: MomentumHomeCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(store.state?.enabled, isFalse);
      expect(find.byType(LGSolidCard), findsNothing);
      expect(find.text('View my profile'), findsNothing);

      final refresh = store.refresh();
      await tester.pump();
      expect(find.byType(MomentumSkeleton), findsOneWidget);
      expect(find.textContaining('XP'), findsNothing);
      failedResponse.completeError(TimeoutException('fixture request timeout'));
      await refresh;
      await tester.pumpAndSettle();
      expect(store.state?.enabled, isFalse);
      expect(store.offline, isTrue);
      final retry = find.text('Momentum is unavailable. Retry');
      expect(retry, findsOneWidget);
      expect(find.text('View my profile'), findsNothing);
      expect(find.textContaining('XP'), findsNothing);

      await tester.tap(retry);
      await tester.pump();
      expect(reads, 3);
      expect(find.byType(MomentumSkeleton), findsOneWidget);
      expect(store.state?.enabled, isFalse);
      expect(find.text('View my profile'), findsNothing);
      enabledResponse.complete(MomentumState(progressFor(7, xp: 137)));
      await tester.pumpAndSettle();
      expect(store.state?.enabled, isTrue);
      expect(store.offline, isFalse);
      expect(find.text('View my profile'), findsOneWidget);
      expect(find.textContaining('137 XP'), findsOneWidget);

      // A later successful disabled response still hides the whole card.
      await store.refresh();
      await tester.pumpAndSettle();
      expect(store.state?.enabled, isFalse);
      expect(store.error, isNull);
      expect(find.byType(LGSolidCard), findsNothing);
      expect(find.byType(LGGlassCard), findsNothing);
      expect(find.text('View my profile'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
      auth.dispose();
      language.dispose();
    },
  );

  for (final action in ['pull', 'retry']) {
    testWidgets(
      'Dashboard $action refresh reveals Momentum only after the server enables it',
      (tester) async {
        final auth = AuthStore();
        await auth.setToken(tokenFor(7));
        final language = LangStore();
        final refresh = RefreshBus();
        final response = Completer<MomentumState>();
        var reads = 0;
        final store = MomentumStore(
          serviceFactory:
              (token) => FakeMomentumService(token, () {
                reads++;
                return reads == 1
                    ? Future.value(
                      MomentumState({'enabled': false, 'user_id': 7}),
                    )
                    : response.future;
              }),
        );
        await store.bind(auth);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthStore>.value(value: auth),
              ChangeNotifierProvider<LangStore>.value(value: language),
              ChangeNotifierProvider<RefreshBus>.value(value: refresh),
              ChangeNotifierProvider<MomentumStore>.value(value: store),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const Scaffold(body: DashboardScreen()),
            ),
          ),
        );
        // The real financial requests fail through Flutter's HTTP override.
        await tester.pumpAndSettle();
        expect(find.text('Unable to load your finances'), findsOneWidget);
        expect(store.state?.enabled, isFalse);
        expect(reads, 1);
        expect(find.text('View my profile'), findsNothing);

        if (action == 'pull') {
          await tester.drag(find.byType(ListView), const Offset(0, 300));
        } else {
          await tester.tap(find.widgetWithText(LGButton, 'Retry'));
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(reads, 2);
        expect(store.state?.enabled, isFalse);
        expect(find.text('View my profile'), findsNothing);

        response.complete(MomentumState(progressFor(7, xp: 137)));
        await tester.pumpAndSettle();
        expect(store.state?.enabled, isTrue);
        expect(store.state?.xp, 137);
        expect(find.text('View my profile'), findsOneWidget);
        expect(find.text('Unable to load your finances'), findsOneWidget);
        expect(auth.token, tokenFor(7));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
        refresh.dispose();
        auth.dispose();
        language.dispose();
      },
    );
  }

  test(
    'verified Pro is user-scoped and local purchase flags cannot grant it',
    () async {
      SharedPreferences.setMockInitialValues({'is_pro_local': true});
      final auth = AuthStore();
      await auth.setToken(tokenFor(7));
      await auth.setLocalPro(true);
      expect(auth.isPro, isFalse);
      auth.setServerPro(true);
      await Future<void>.delayed(Duration.zero);
      expect(auth.isPro, isTrue);
      await auth.setToken(tokenFor(8));
      expect(auth.isPro, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('verified_pro_7'), isNull);
      auth.dispose();
    },
  );
  test(
    'all 168 supplied SVG variants load in the installed Flutter renderer',
    () async {
      final manifest = object(
        jsonDecode(
          await File('assets/momentum/assets/manifest.json').readAsString(),
        ),
      );
      expect(manifest['badges'], hasLength(34));
      final paths =
          manifest.values
              .whereType<List>()
              .expand((rows) => rows)
              .map(object)
              .expand((item) => object(item['files']).values.cast<String>())
              .toSet();
      expect(paths, hasLength(168));
      for (final path in paths) {
        final picture = await vg.loadPicture(
          SvgStringLoader(await File('assets/momentum/$path').readAsString()),
          null,
        );
        expect(picture.size, const Size(64, 64), reason: path);
        picture.picture.dispose();
      }
    },
  );

  testWidgets(
    'review requires explicit confirmation and retry preserves the event id',
    (tester) async {
      final auth = AuthStore();
      await auth.setToken(tokenFor(7));
      final service = FakeMomentumService(
          tokenFor(7),
          () async => MomentumState(progressFor(7)),
        )
        ..snapshot = {
          'snapshot_id': clientEventId(),
          'period': '2026-W39',
          'expires_at':
              DateTime.now()
                  .toUtc()
                  .add(const Duration(minutes: 15))
                  .toIso8601String(),
          'sections': [
            {
              'key': 'accounts',
              'title': {'en': 'Accounts', 'es': 'Cuentas'},
              'applicable': true,
              'data': [
                {'name': 'Checking', 'balance': 42},
              ],
            },
            {
              'key': 'obligations',
              'title': {'en': 'Obligations', 'es': 'Obligaciones'},
              'applicable': false,
              'data': [],
            },
          ],
        };
      final sent = <Json>[];
      service.submit = (payload) async {
        sent.add(payload);
        if (sent.length == 1) throw StateError('offline');
        return MomentumState(progressFor(7));
      };
      final store = MomentumStore(serviceFactory: (_) => service);
      await store.bind(auth);
      final language = LangStore();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MomentumStore>.value(value: store),
            ChangeNotifierProvider<LangStore>.value(value: language),
          ],
          child: MaterialApp(
            navigatorKey: navigator,
            theme: AppTheme.light(),
            home: const Scaffold(),
          ),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder:
              (_) =>
                  const MomentumReviewScreen(kind: 'activation_first_insight'),
        ),
      );
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
      expect(
        tester
            .widget<LGButton>(find.widgetWithText(LGButton, 'Confirm review'))
            .onPressed,
        isNull,
      );
      expect(find.text('Name: Checking'), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.ensureVisible(
        find.widgetWithText(LGButton, 'Confirm review'),
      );
      await tester.tap(find.widgetWithText(LGButton, 'Confirm review'));
      await tester.pumpAndSettle();
      expect(sent, hasLength(1));
      expect(sent.first['confirmed_sections'], ['accounts']);
      await tester.ensureVisible(
        find.widgetWithText(LGButton, 'Confirm review'),
      );
      await tester.tap(find.widgetWithText(LGButton, 'Confirm review'));
      await tester.pumpAndSettle();
      expect(sent, hasLength(2));
      expect(sent.last['event_id'], sent.first['event_id']);
      expect(sent.last['occurred_at'], sent.first['occurred_at']);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
      auth.dispose();
      language.dispose();
    },
  );

  for (final lang in ['en', 'es']) {
    for (final dark in [false, true]) {
      testWidgets(
        'Momentum card $lang ${dark ? 'dark' : 'light'} at large text has no overflow',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final store = MomentumStore()..state = MomentumState(progressFor(7));
          final language = LangStore();
          await language.setLang(lang);
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<MomentumStore>.value(value: store),
                ChangeNotifierProvider<LangStore>.value(value: language),
              ],
              child: MaterialApp(
                theme: dark ? AppTheme.dark() : AppTheme.light(),
                home: MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                  child: const Scaffold(
                    body: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: MomentumHomeCard(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text(lang == 'es' ? 'Ver mi perfil' : 'View my profile'),
            findsOneWidget,
          );
          await tester.pumpWidget(const SizedBox.shrink());
          store.dispose();
          language.dispose();
        },
      );
    }
  }
}
