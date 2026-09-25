import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/momentum/service.dart';
import 'package:mobile/services/api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.finsight/client_context');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => {'timezone': 'UTC'});
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  testWidgets(
    'Momentum accepts authoritative progress after a slow evaluation',
    (tester) async {
      final response = http.runWithClient(
        () => MomentumService('test-session').me(),
        () => MockClient((request) async {
          expectSync(request.url.path, '/api/engagement/me');
          await Future<void>.delayed(const Duration(seconds: 40));
          return http.Response(
            jsonEncode({'enabled': true, 'user_id': 7, 'lifetime_xp': 90}),
            200,
          );
        }),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 40));
      final state = await response;
      expect(state.enabled, isTrue);
      expect(state.userId, 7);
      expect(state.xp, 90);
    },
  );

  testWidgets('an unresponsive Momentum evaluation still has a deadline', (
    tester,
  ) async {
    final response = http.runWithClient(
      () => MomentumService('test-session').me(),
      () => MockClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 100));
        return http.Response('{}', 200);
      }),
    );
    final assertion = expectLater(response, throwsA(isA<Exception>()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 90));
    await assertion;
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('ordinary API reads keep the normal 15 second deadline', (
    tester,
  ) async {
    final response = http.runWithClient(
      () => ApiClient().get('/api/accounts'),
      () => MockClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 20));
        return http.Response('[]', 200);
      }),
    );
    final assertion = expectLater(response, throwsA(isA<Exception>()));
    await tester.pump(const Duration(seconds: 15));
    await assertion;
    await tester.pump(const Duration(seconds: 5));
  });

  test(
    'preferences returns the complete server snapshot for immediate adoption',
    () async {
      var calls = 0;
      final state = await http.runWithClient(
        () => MomentumService('test-session').preferences({'locale': 'es'}),
        () => MockClient((request) async {
          calls++;
          expect(request.method, 'POST');
          expect(request.url.path, '/api/engagement/preferences');
          return http.Response(
            jsonEncode({
              'enabled': true,
              'user_id': 7,
              'lifetime_xp': 90,
              'preferences': {'locale': 'es'},
            }),
            200,
          );
        }),
      );
      expect(calls, 1);
      expect(state.xp, 90);
      expect(state.preferences['locale'], 'es');
    },
  );
}
