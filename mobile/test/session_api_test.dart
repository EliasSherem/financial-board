import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/services/api.dart';
import 'package:mobile/state/auth_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _tokenFor(String revision) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'id': 71042, 'jti': revision}))).replaceAll('=', '')}.signature';

Matcher _apiError(int status, {String? code}) => isA<ApiException>()
    .having((error) => error.statusCode, 'statusCode', status)
    .having((error) => error.code, 'code', code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final token = _tokenFor('original');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AuthStore> restore({bool locked = false}) async {
    SharedPreferences.setMockInitialValues({
      'auth_token': token,
      'biometric_enabled': locked,
    });
    final auth = AuthStore();
    addTearDown(auth.dispose);
    await auth.load();
    return auth;
  }

  test(
    'a locked session rejects reads and writes before making HTTP requests',
    () async {
      final auth = await restore(locked: true);
      final api = ApiClient()..setToken(token);
      final requests = <http.Request>[];
      final directory = await Directory.systemTemp.createTemp(
        'finsight-session-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final receipt = await File(
        '${directory.path}/receipt.png',
      ).writeAsBytes([0x89, 0x50, 0x4e, 0x47]);
      await http.runWithClient(
        () async {
          final calls = <Future<dynamic> Function()>[
            () => api.get('/api/accounts'),
            () =>
                api.post('/api/accounts', body: {'name': 'Synthetic account'}),
            () =>
                api.put('/api/accounts/1', body: {'name': 'Synthetic account'}),
            () => api.patch('/api/accounts/1', body: {'is_active': false}),
            () => api.delete('/api/accounts/1'),
            () => api.uploadFile(
              '/api/receipts/drafts',
              file: receipt,
              fieldName: 'image',
            ),
          ];
          for (final call in calls) {
            await expectLater(
              call(),
              throwsA(_apiError(423, code: 'SESSION_LOCKED')),
            );
          }
        },
        () => MockClient((request) async {
          requests.add(request);
          return http.Response('[]', 200);
        }),
      );

      expect(requests, isEmpty);
      expect(auth.token, token);
      expect(auth.isLocked, isTrue);
      expect(
        (await SharedPreferences.getInstance()).getString('auth_token'),
        token,
      );
    },
  );

  test(
    'the same API client can read after successful session unlock',
    () async {
      final auth = await restore(locked: true);
      final api = ApiClient()..setToken(token);
      final requests = <http.Request>[];
      await http.runWithClient(
        () async {
          await expectLater(
            api.get('/api/accounts'),
            throwsA(_apiError(423, code: 'SESSION_LOCKED')),
          );
          expect(requests, isEmpty);

          expect(await auth.unlock(expectedToken: token), isTrue);
          final result = await api.get('/api/accounts');
          expect(result, [
            {'id': 1, 'name': 'Synthetic account'},
          ]);
        },
        () => MockClient((request) async {
          requests.add(request);
          return http.Response('[{"id":1,"name":"Synthetic account"}]', 200);
        }),
      );

      expect(requests, hasLength(1));
      expect(requests.single.headers['authorization'], 'Bearer $token');
      expect(auth.isAuthenticated, isTrue);
      expect(auth.token, token);
    },
  );

  test(
    'a transient 503 preserves the authenticated and persisted session',
    () async {
      final auth = await restore();
      final api = ApiClient()..setToken(token);
      var requests = 0;
      await http.runWithClient(
        () async {
          await expectLater(api.get('/api/accounts'), throwsA(_apiError(503)));
        },
        () => MockClient((request) async {
          requests++;
          expect(request.headers['authorization'], 'Bearer $token');
          return http.Response('{"message":"Temporarily unavailable"}', 503);
        }),
      );

      expect(requests, 1);
      expect(auth.token, token);
      expect(auth.isAuthenticated, isTrue);
      expect(
        (await SharedPreferences.getInstance()).getString('auth_token'),
        token,
      );
    },
  );

  test(
    'a 401 for the current token invalidates it even with biometrics enabled',
    () async {
      final auth = await restore();
      await auth.setBiometricEnabled(true);
      final api = ApiClient()..setToken(token);
      var requests = 0;
      await http.runWithClient(
        () async {
          await expectLater(api.get('/api/accounts'), throwsA(_apiError(401)));
          // ApiClient starts invalidation without awaiting storage persistence.
          await Future<void>.delayed(Duration.zero);
        },
        () => MockClient((request) async {
          requests++;
          expect(request.headers['authorization'], 'Bearer $token');
          return http.Response('{"message":"Session expired"}', 401);
        }),
      );

      expect(requests, 1);
      expect(auth.hasToken, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.isLocked, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getString('auth_token'),
        isNull,
      );
    },
  );

  for (final updateClientToken in [false, true]) {
    test(
      'a delayed old-token 401 preserves the new session '
      'with ${updateClientToken ? 'an updated' : 'the original'} API client token',
      () async {
        final auth = await restore();
        final api = ApiClient()..setToken(token);
        final currentToken = _tokenFor('rotated');
        final started = Completer<void>();
        final response = Completer<http.Response>();
        final requests = <http.Request>[];

        await http.runWithClient(
          () async {
            final rejection = expectLater(
              api.get('/api/accounts'),
              throwsA(_apiError(401)),
            );
            await started.future;
            // The old request is already in flight when the session rotates.
            await auth.setToken(currentToken);
            if (updateClientToken) api.setToken(currentToken);
            response.complete(
              http.Response('{"message":"Session expired"}', 401),
            );
            await rejection;
            await Future<void>.delayed(Duration.zero);
          },
          () => MockClient((request) {
            requests.add(request);
            started.complete();
            return response.future;
          }),
        );

        expect(requests, hasLength(1));
        expect(requests.single.headers['authorization'], 'Bearer $token');
        expect(auth.token, currentToken);
        expect(auth.isAuthenticated, isTrue);
        expect(
          (await SharedPreferences.getInstance()).getString('auth_token'),
          currentToken,
        );
      },
    );
  }
}
