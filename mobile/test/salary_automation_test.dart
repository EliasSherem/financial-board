import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/lang_store.dart';
import 'package:mobile/screens/calendar_screen.dart' show SalaryRule;
import 'package:mobile/screens/settings_screen.dart';
import 'package:mobile/services/api.dart';
import 'package:mobile/services/data_service.dart';
import 'package:mobile/theme.dart';
import 'package:provider/provider.dart';

class SalaryApi extends ApiClient {
  List<Map<String, dynamic>> rows = [];
  final writes = <Map<String, dynamic>>[];
  Completer<dynamic>? pendingCreate;
  int creates = 0;
  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Headers? headers,
    Duration? timeout,
  }) async {
    if (path == '/api/salaries') return rows;
    if (path == '/api/accounts') {
      return [
        {'id': 1, 'name': 'First account', 'balance': 100, 'is_active': 1},
        {'id': 2, 'name': 'Chosen account', 'balance': 100, 'is_active': 1},
      ];
    }
    throw StateError('Unexpected test route');
  }

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    Headers? headers,
    Duration? timeout,
  }) async {
    writes.add(Map<String, dynamic>.from(body as Map));
    return {'id': 5, ...writes.last};
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Headers? headers,
    Duration? timeout,
  }) async {
    creates++;
    writes.add(Map<String, dynamic>.from(body as Map));
    return pendingCreate?.future ?? Future.value({'id': 5, ...writes.last});
  }
}

void main() {
  test(
    'salary DTO preserves inactive, account and calendar state from the wire',
    () async {
      final api =
          SalaryApi()
            ..rows = [
              {
                'id': 5,
                'name': 'Pay',
                'amount': '250.00',
                'schedule': 'Weekly',
                'weekday': 4,
                'day': null,
                'account_id': 2,
                'account_name': 'Chosen account',
                'is_active': 0,
              },
            ];
      final row = (await DataService(api).getSalaryRules()).single;
      expect(row['isActive'], false);
      expect(row['accountId'], 2);
      expect(row['accountName'], 'Chosen account');
      final calendar = SalaryRule.fromJson(row);
      expect(calendar.isActive, false);
      expect(calendar.accountId, 2);
      expect(calendar.weekday, 4);
    },
  );

  test(
    'toggle updates only active; explicit nullable edits still clear selected fields',
    () async {
      final api = SalaryApi();
      final data = DataService(api);
      await data.updateSalaryRule(id: 5, isActive: false);
      expect(api.writes.single, {'is_active': false});
      await data.updateSalaryRule(
        id: 5,
        schedule: 'Monthly',
        weekday: null,
        day: 20,
        accountId: null,
      );
      expect(api.writes.last, {
        'schedule': 'Monthly',
        'weekday': null,
        'day': 20,
        'account_id': null,
      });
    },
  );

  Future<void> openSheet(WidgetTester tester, SalaryApi api) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final language = LangStore();
    addTearDown(language.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: language,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed:
                        () => showSalaryAutomation(
                          context,
                          data: DataService(api),
                        ),
                    child: const Text('Open salaries'),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open salaries'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'editing an inactive rule retains its chosen account and schedule',
    (tester) async {
      final api =
          SalaryApi()
            ..rows = [
              {
                'id': 5,
                'name': 'Pay',
                'amount': 250,
                'schedule': 'Weekly',
                'weekday': 4,
                'day': null,
                'account_id': 2,
                'account_name': 'Chosen account',
                'is_active': 0,
              },
            ];
      await openSheet(tester, api);
      expect(tester.widget<Switch>(find.byType(Switch)).value, false);
      expect(find.textContaining('Chosen account'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        false,
      );
      await tester.tap(find.byKey(const ValueKey('salary-save')));
      await tester.pumpAndSettle();
      expect(api.writes.single, {
        'name': 'Pay',
        'amount': 250.0,
        'schedule': 'Weekly',
        'weekday': 4,
        'day': null,
        'account_id': 2,
        'is_active': false,
      });
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'double save makes one request and an error keeps the entered rule open',
    (tester) async {
      final api = SalaryApi()..pendingCreate = Completer<dynamic>();
      await openSheet(tester, api);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'My salary');
      await tester.enterText(find.byType(TextField).at(1), '250');
      final save = find.byKey(const ValueKey('salary-save'));
      // A second tap before the next frame must still hit the synchronous guard.
      await tester.tap(save);
      await tester.tap(save);
      await tester.pump();
      expect(api.creates, 1);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      api.pendingCreate!.completeError(
        const ApiException(503, 'Synthetic failure'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byKey(const ValueKey('salary-save-error')), findsOneWidget);
      expect(find.text('My salary'), findsOneWidget);
      expect(api.creates, 1);
      // Only a new, explicit action can submit again.
      api.pendingCreate = null;
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(api.creates, 2);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
