import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile/lang_store.dart';
import 'package:mobile/liquid_glass/liquid_glass.dart';
import 'package:mobile/momentum/models.dart';
import 'package:mobile/momentum/screens.dart';
import 'package:mobile/momentum/service.dart';
import 'package:mobile/momentum/store.dart';
import 'package:mobile/momentum/xp_chart.dart';
import 'package:mobile/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Json _badge(
  String key,
  String title, {
  bool earned = false,
  bool available = true,
}) => {
  'key': key,
  'title': {'en': title, 'es': 'Insignia $title'},
  'requirement': {'en': 'Requirement for $title', 'es': 'Requisito de $title'},
  'reason':
      available
          ? null
          : {
            'en': 'Real project progress is not available.',
            'es': 'El progreso real del proyecto no está disponible.',
          },
  'completed_at': earned ? '2026-09-20T12:00:00Z' : null,
  'seen_at': null,
  'available': available,
  'progress': earned ? 3 : 1,
  'target': 3,
  'xp': 50,
};

Json _profile() => {
  'enabled': true,
  'user_id': 7,
  'lifetime_xp': 90,
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
    'key': 'INTERNAL-WEEK-KEY',
    'timezone': 'INTERNAL-TIMEZONE',
  },
  'coachmark_seen': true,
  'backfill': {'unseen': true},
  'achievements': [
    _badge('clear_view', 'Clear View', earned: true),
    _badge('account_organizer', 'Account Organizer', earned: true),
    _badge('money_mapper', 'Money Mapper'),
    _badge('goal_builder_1', 'Goal Builder', available: false),
    _badge('weekly_rhythm', 'Weekly Rhythm'),
    _badge('analytics_explorer', 'Analytics Explorer'),
  ],
  'missions': [
    {
      'key': 'weekly_summary',
      'scope': 'weekly',
      'slot': 'review',
      'status': 'active',
      'review': true,
      'title': {'en': 'Review your week', 'es': 'Revisa tu semana'},
      'requirement': {
        'en': 'Confirm the current weekly snapshot.',
        'es': 'Confirma la revisión semanal actual.',
      },
      'target': 1,
      'progress': 0,
      'nominal_xp': 40,
      'granted_xp': 0,
      'deeplink': '/momentum',
    },
  ],
};

class _ReviewService extends MomentumService {
  _ReviewService() : super('synthetic-session');
  @override
  Future<Json> review(String kind) async => {
    'snapshot_id': 'synthetic-snapshot',
    'period': '2026-W39',
    'expires_at':
        DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
    'sections': <Json>[],
  };
}

class _ProfileStore extends MomentumStore {
  _ProfileStore() {
    state = MomentumState(_profile());
  }
  final events = <String>[];
  final seen = <String>[];
  final _review = _ReviewService();
  @override
  MomentumService get service => _review;
  @override
  Future<void> refresh({bool force = true}) async {}
  @override
  Future<void> event(
    String type, {
    Json fields = const {},
    bool queueOnFailure = true,
  }) async {
    events.add(type);
  }

  @override
  Future<void> markSeen(String key) async {
    seen.add(key);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> mount(
    WidgetTester tester,
    _ProfileStore store,
    Widget screen, {
    String language = 'en',
    bool dark = false,
    double scale = 1,
  }) async {
    final lang = LangStore();
    await lang.setLang(language);
    addTearDown(lang.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LangStore>.value(value: lang),
          ChangeNotifierProvider<MomentumStore>.value(value: store),
        ],
        child: MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          locale: Locale(language),
          supportedLocales: const [Locale('en'), Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: child!,
              ),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'collection keeps requirements in tap details and marks only an opened earned badge seen',
    (tester) async {
      final store = _ProfileStore();
      addTearDown(store.dispose);
      await mount(tester, store, const AchievementsScreen());
      expect(find.text('Requirement for Clear View'), findsNothing);
      expect(store.seen, isEmpty);
      await tester.tap(find.byKey(const ValueKey('momentum-badge-clear_view')));
      await tester.pumpAndSettle();
      expect(find.text('Requirement for Clear View'), findsOneWidget);
      expect(find.text('3/3 · 50 XP'), findsOneWidget);
      expect(find.textContaining('Earned on'), findsOneWidget);
      await tester.tap(find.widgetWithText(LGButton, 'Done'));
      await tester.pumpAndSettle();
      expect(store.seen, ['clear_view']);
      final unavailable = find.byKey(
        const ValueKey('momentum-badge-goal_builder_1'),
      );
      await tester.ensureVisible(unavailable);
      await tester.tap(unavailable);
      await tester.pumpAndSettle();
      expect(
        find.text('Real project progress is not available.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(LGButton, 'Done'));
      await tester.pumpAndSettle();
      expect(store.seen, ['clear_view']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'profile discloses activities and preserves the explicit review flow',
    (tester) async {
      final store = _ProfileStore();
      addTearDown(store.dispose);
      await mount(tester, store, const MomentumScreen());
      expect(find.text('Review your week'), findsNothing);
      expect(find.byType(MomentumXpChart), findsNothing);
      expect(find.textContaining('INTERNAL-'), findsNothing);
      expect(store.events, isEmpty);
      final activities = find.byKey(const Key('momentum-open-activities'));
      await tester.scrollUntilVisible(
        activities,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(activities);
      await tester.pumpAndSettle();
      expect(find.byType(MomentumActivitiesScreen), findsOneWidget);
      expect(find.text('Review your week'), findsOneWidget);
      expect(find.text('Confirm the current weekly snapshot.'), findsNothing);
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm the current weekly snapshot.'), findsOneWidget);
      expect(store.events, isEmpty);
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(MomentumReviewScreen), findsOneWidget);
      expect(find.textContaining('Only the final confirmation'), findsNothing);
      await tester.tap(find.byKey(const Key('momentum-review-help')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Only the final confirmation'),
        findsOneWidget,
      );
      expect(store.events, isEmpty);
      await tester.tap(find.widgetWithText(TextButton, 'Done'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LGButton>(find.widgetWithText(LGButton, 'Confirm review'))
            .onPressed,
        isNull,
      );
      expect(store.events, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'existing-progress notice stays unacknowledged until its button is pressed',
    (tester) async {
      final store = _ProfileStore();
      addTearDown(store.dispose);
      await mount(tester, store, const MomentumScreen());
      expect(store.events, isEmpty);
      final acknowledgment = find.byKey(const Key('momentum-notice-ack'));
      await tester.scrollUntilVisible(
        acknowledgment,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(store.events, isEmpty);
      await tester.tap(acknowledgment);
      await tester.pumpAndSettle();
      expect(store.events, ['backfill_seen']);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'completed activities stay collapsed while full requirements remain available at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = _ProfileStore();
      addTearDown(store.dispose);
      final data = _profile();
      data['missions'] = [
        ...data['missions'] as List,
        {
          ...object((data['missions'] as List).first),
          'key': 'completed_fixture',
          'slot': 'goal',
          'status': 'completed',
          'title': {'en': 'Finished activity', 'es': 'Actividad terminada'},
          'requirement': {
            'en': 'The full verified requirement.',
            'es': 'El requisito completo verificado.',
          },
          'progress': 1,
          'granted_xp': 25,
        },
      ];
      store.state = MomentumState(data);
      await mount(
        tester,
        store,
        const MomentumActivitiesScreen(),
        language: 'es',
        dark: true,
        scale: 2,
      );
      expect(find.text('Revisa tu semana'), findsOneWidget);
      expect(find.text('Actividad terminada'), findsNothing);
      final completed = find.byKey(
        const PageStorageKey('momentum-completed-activities'),
      );
      await tester.scrollUntilVisible(
        completed,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(completed);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Completadas (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Actividad terminada'), findsOneWidget);
      expect(find.text('El requisito completo verificado.'), findsNothing);
      final details = find.byKey(
        const PageStorageKey('momentum-mission-details-completed_fixture'),
      );
      await tester.ensureVisible(details);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: details, matching: find.text('Detalles')),
      );
      await tester.pumpAndSettle();
      expect(find.text('El requisito completo verificado.'), findsOneWidget);
      expect(find.text('25 XP obtenidos'), findsOneWidget);
      expect(store.events, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final language in ['en', 'es']) {
    for (final dark in [false, true]) {
      testWidgets(
        'profile and gallery remain usable at 320px / 200% in $language ${dark ? 'dark' : 'light'}',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          final store = _ProfileStore();
          addTearDown(store.dispose);
          try {
            await mount(
              tester,
              store,
              const MomentumScreen(),
              language: language,
              dark: dark,
              scale: 2,
            );
            expect(tester.takeException(), isNull);
            final collection = find.byKey(
              const Key('momentum-open-collection'),
            );
            await tester.scrollUntilVisible(
              collection,
              250,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            await tester.ensureVisible(collection);
            await tester.pumpAndSettle();
            expect(collection.hitTestable(), findsOneWidget);
            await tester.tap(collection);
            await tester.pumpAndSettle();
            expect(find.byType(AchievementsScreen), findsOneWidget);
            final badge = find.byKey(
              const ValueKey('momentum-badge-clear_view'),
            );
            await tester.ensureVisible(badge);
            await tester.pumpAndSettle();
            final node = tester.getSemantics(badge);
            expect(node.label, contains('Clear View'));
            expect(
              node.getSemanticsData().hasAction(SemanticsAction.tap),
              isTrue,
            );
            await tester.tap(badge);
            await tester.pumpAndSettle();
            expect(
              find.text(
                language == 'es'
                    ? 'Requisito de Clear View'
                    : 'Requirement for Clear View',
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
