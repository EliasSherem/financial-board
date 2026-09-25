import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:mobile/screens/login_screen.dart';
import 'package:mobile/screens/password_recovery_screen.dart';
import 'package:mobile/services/session_lifecycle.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final token = List.filled(43, 'a').join();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    binding.platformDispatcher.defaultRouteNameTestValue = '/';
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/local_auth'),
      (_) async => false,
    );
  });

  tearDown(() {
    binding.platformDispatcher.clearDefaultRouteNameTestValue();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/local_auth'),
      null,
    );
  });

  Future<void> start(WidgetTester tester, [String route = '/']) async {
    binding.platformDispatcher.defaultRouteNameTestValue = route;
    await tester.pumpWidget(const FinancialBoardRoot());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> returnToLogin(WidgetTester tester) async {
    expect(sessionNavigatorKey.currentState!.canPop(), isTrue);
    sessionNavigatorKey.currentState!.popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ResetPasswordScreen), findsNothing);
    expect(sessionNavigatorKey.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  }

  testWidgets('normal startup renders login and resolves the named root', (
    tester,
  ) async {
    await start(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(sessionNavigatorKey.currentState!.canPop(), isFalse);
    sessionNavigatorKey.currentState!.pushNamed('/');
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    await returnToLogin(tester);
  });

  testWidgets('unknown initial route falls back to login', (tester) async {
    await start(tester, '/unknown');
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(sessionNavigatorKey.currentState!.canPop(), isFalse);
  });

  for (final route in [
    'financialboard://reset-password#token=$token',
    '/reset-password#token=$token',
  ]) {
    testWidgets('cold recovery preserves the login underneath: $route', (
      tester,
    ) async {
      await start(tester, route);
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(
        tester
            .widget<ResetPasswordScreen>(find.byType(ResetPasswordScreen))
            .token,
        token,
      );
      expect(sessionRouteObserver.current, '/reset-password');
      await returnToLogin(tester);
    });
  }

  for (final route in [
    'financialboard://reset-password#token=invalid',
    'https://untrusted.invalid/reset-password#token=$token',
  ]) {
    testWidgets('invalid recovery remains safe and can go back: $route', (
      tester,
    ) async {
      await start(tester, route);
      expect(find.text('Link unavailable'), findsOneWidget);
      expect(
        tester
            .widget<ResetPasswordScreen>(find.byType(ResetPasswordScreen))
            .token,
        isNull,
      );
      await returnToLogin(tester);
    });
  }

  testWidgets('platform recovery link opens while the app is running', (
    tester,
  ) async {
    await start(tester);
    expect(
      await binding.handlePushRoute(
        'financialboard://reset-password#token=$token',
      ),
      isTrue,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ResetPasswordScreen>(find.byType(ResetPasswordScreen))
          .token,
      token,
    );
    expect(sessionRouteObserver.current, '/reset-password');
    await returnToLogin(tester);
  });

  testWidgets('warm external URI cannot become a trusted relative reset link', (
    tester,
  ) async {
    await start(tester);
    expect(
      await binding.handlePushRoute(
        'https://untrusted.invalid/reset-password#token=$token',
      ),
      isTrue,
    );
    await tester.pumpAndSettle();
    expect(find.text('Link unavailable'), findsOneWidget);
    expect(
      tester
          .widget<ResetPasswordScreen>(find.byType(ResetPasswordScreen))
          .token,
      isNull,
    );
    expect(sessionRouteObserver.current, '/reset-password');
    await returnToLogin(tester);
  });
}
