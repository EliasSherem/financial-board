import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
// The SDK's resolved platform interface is its supported fake-store boundary.
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:mobile/services/api.dart';
import 'package:mobile/services/purchase_service.dart';
import 'package:mobile/state/auth_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStore extends InAppPurchasePlatform {
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  int completions = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completions++;
  }
}

PurchaseDetails _purchase(String id) => PurchaseDetails(
  productID: 'synthetic_subscription',
  purchaseID: id,
  transactionDate: '1700000000000',
  verificationData: PurchaseVerificationData(
    localVerificationData: 'synthetic-$id',
    serverVerificationData: 'synthetic-$id',
    source: 'google_play',
  ),
  status: PurchaseStatus.purchased,
)..pendingCompletePurchase = true;

void main() {
  testWidgets('locked purchases wait for unlock and a late lock error retries once', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final fakeStore = _FakeStore();
    InAppPurchasePlatform.instance = fakeStore;
    // Create the SDK singleton without starting a real native BillingClient.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final purchases = PurchaseService();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final token =
        'header.${base64Url.encode(utf8.encode(jsonEncode({'id': 71102}))).replaceAll('=', '')}.signature';
    final auth = AuthStore();
    await auth.setToken(token);
    await auth.setBiometricEnabled(true);
    final requests = <http.Request>[];
    final lateLock = Completer<http.Response>();
    var lateAttempts = 0;
    var repeatedLockAttempts = 0;
    late BuildContext purchaseContext;

    await http.runWithClient(
      () async {
        try {
          await tester.pumpWidget(
            ChangeNotifierProvider<AuthStore>.value(
              value: auth,
              child: MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (context) {
                      purchaseContext = context;
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            ),
          );
          await purchases.initialize(purchaseContext);
          await auth.lock();
          fakeStore.updates.add([_purchase('received-locked')]);
          await tester.pumpAndSettle();
          expect(requests, isEmpty);
          expect(auth.isPro, isFalse);
          expect(fakeStore.completions, 0);

          expect(await auth.unlock(expectedToken: token), isTrue);
          await tester.pumpAndSettle();
          expect(requests.map((r) => r.url.path), [
            '/api/play/link',
            '/api/me',
          ]);
          expect(
            requests.every(
              (r) => r.headers['Authorization'] == 'Bearer $token',
            ),
            isTrue,
          );
          expect(auth.isPro, isTrue);
          expect(
            fakeStore.completions,
            0,
            reason: 'Android ACK remains owned by the backend',
          );

          // The unlock notification occurs before the pending delivery learns it
          // was blocked. That delivery must arrange its own one-time wake-up.
          requests.clear();
          fakeStore.updates.add([_purchase('late-lock')]);
          await tester.pump();
          expect(lateAttempts, 1);
          await auth.lock();
          expect(await auth.unlock(expectedToken: token), isTrue);
          await tester.pump();
          expect(lateAttempts, 1);
          lateLock.completeError(
            const ApiException(423, 'Unlock first', code: 'SESSION_LOCKED'),
          );
          await tester.pumpAndSettle();
          expect(lateAttempts, 2);
          expect(requests.map((r) => r.url.path), [
            '/api/play/link',
            '/api/play/link',
            '/api/me',
          ]);
          expect(auth.token, token);
          expect(fakeStore.completions, 0);

          // A repeated lock error cannot create an unbounded immediate retry loop.
          fakeStore.updates.add([_purchase('repeated-lock')]);
          await tester.pumpAndSettle();
          expect(repeatedLockAttempts, 2);
          expect(tester.takeException(), isNull);
        } finally {
          await auth.logout(force: true);
          await fakeStore.updates.close();
          await tester.pumpWidget(const SizedBox.shrink());
          auth.dispose();
          debugDefaultTargetPlatformOverride = null;
        }
      },
      () => MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/play/link') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final receipt = body['purchaseToken'];
          if (receipt == 'synthetic-late-lock' && ++lateAttempts == 1) {
            return lateLock.future;
          }
          if (receipt == 'synthetic-repeated-lock') {
            repeatedLockAttempts++;
            throw const ApiException(
              423,
              'Unlock first',
              code: 'SESSION_LOCKED',
            );
          }
          return http.Response('{"verified":true}', 200);
        }
        if (request.url.path == '/api/me') {
          return http.Response('{"is_pro":true}', 200);
        }
        throw StateError('Unexpected endpoint: ${request.url.path}');
      }),
    );
  });
}
