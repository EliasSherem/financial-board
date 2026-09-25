import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile/lang_store.dart';
import 'package:mobile/models.dart';
import 'package:mobile/services/api.dart';
import 'package:mobile/services/data_service.dart';
import 'package:mobile/state/auth_store.dart';
import 'package:mobile/theme.dart';
import 'package:mobile/widgets/new_transaction_dialog.dart';

class _PendingFormData extends DataService {
  _PendingFormData() : super(ApiClient());

  final requested = <String>{};
  final accounts = Completer<List<Account>>();
  final projects = Completer<List<Project>>();
  final categories = Completer<List<ExpenseCategory>>();

  @override
  Future<List<Account>> getAccounts() {
    requested.add('accounts');
    return accounts.future;
  }

  @override
  Future<List<Project>> getProjects() {
    requested.add('projects');
    return projects.future;
  }

  @override
  Future<List<ExpenseCategory>> getExpenseCategories() {
    requested.add('categories');
    return categories.future;
  }
}

void main() {
  for (final projectsAllowed in [true, false]) {
    testWidgets(
      'transaction form loads independent data together '
      'and preserves ${projectsAllowed ? 'selections' : 'the project fallback'}',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = AuthStore();
        final language = LangStore();
        addTearDown(auth.dispose);
        addTearDown(language.dispose);
        final data = _PendingFormData();
        final initial = TransactionItem(
          id: 5,
          accountId: 12,
          date: DateTime(2026, 9, 20),
          description: 'Train ticket',
          amount: 25,
          type: 'Expense',
          categoryId: 7,
          projectId: 9,
          projectName: 'Autumn trip',
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthStore>.value(value: auth),
              ChangeNotifierProvider<LangStore>.value(value: language),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: Builder(
                builder:
                    (context) => Scaffold(
                      body: TextButton(
                        onPressed: () {
                          showNewTransactionDialog(
                            context,
                            data,
                            initial: initial,
                          );
                        },
                        child: const Text('Edit transaction'),
                      ),
                    ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Edit transaction'));
        await tester.pump();

        // A slow account response must not postpone the other requests.
        expect(data.requested, {'accounts', 'projects', 'categories'});
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        data.categories.complete([
          const ExpenseCategory(
            id: 7,
            name: 'Transport',
            icon: 'category',
            subcategories: [],
          ),
        ]);
        if (projectsAllowed) {
          data.projects.complete([
            Project(
              id: 9,
              name: 'Autumn trip',
              budget: 200,
              spent: 25,
              status: 'Active',
            ),
          ]);
        } else {
          data.projects.completeError(const ApiException(403, 'Pro required'));
        }
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        data.accounts.complete([
          Account(id: 12, name: 'Travel account', balance: 200, isActive: true),
        ]);
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Train ticket'), findsOneWidget);
        expect(find.text('25.00'), findsOneWidget);
        expect(find.text('Travel account'), findsWidgets);
        expect(find.text('Transport'), findsOneWidget);
        expect(
          find.text('Autumn trip', skipOffstage: false),
          projectsAllowed ? findsWidgets : findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
