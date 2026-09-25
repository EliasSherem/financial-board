import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/services/analytics_service.dart';
import 'package:mobile/services/api.dart';
import 'package:mobile/state/auth_store.dart';

class AnalyticsAuth extends AuthStore {
  bool unlocked = true;
  int identity = 7;
  @override
  bool get isInitialized => true;
  @override
  bool get isAuthenticated => unlocked;
  @override
  String get token => 'analytics-session-$identity';
  @override
  int get userId => identity;
}

class AnalyticsApi extends ApiClient {
  int preferenceReads = 0;
  int preferenceWrites = 0;
  final List<List<dynamic>> batches = [];
  Future<dynamic> Function(int)? readPreference;
  Future<dynamic> Function(int, bool)? writePreference;
  Future<dynamic> Function(int)? sendEvents;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Headers? headers,
    Duration? timeout,
  }) {
    expect(path, '/api/analytics/preferences');
    preferenceReads++;
    return readPreference?.call(preferenceReads) ??
        Future.value({'enabled': true});
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Headers? headers,
    Duration? timeout,
  }) {
    final payload = body! as Map;
    if (path == '/api/analytics/preferences') {
      preferenceWrites++;
      final value = payload['enabled'] as bool;
      return writePreference?.call(preferenceWrites, value) ??
          Future.value({'enabled': value});
    }
    expect(path, '/api/analytics/events');
    batches.add(List<dynamic>.from(payload['events'] as List));
    return sendEvents?.call(batches.length) ??
        Future.error(StateError('Fixture offline'));
  }
}

Map<String, dynamic> queuedEvent() => {
  'event_id': 'b4c055c8-0327-4a05-af1b-c6664b32d151',
  'event_type': 'screen_view',
  'client_occurred_at': DateTime.now().toUtc().toIso8601String(),
};

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.finsight/client_context'),
      (_) async => {'timezone': 'UTC', 'app_version': 'test', 'build': 'test'},
    );
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.finsight/client_context'),
      null,
    );
  });

  testWidgets(
    'locked or background bind cannot start a late timer; foreground resumes and background preserves queue',
    (tester) async {
      final queued = queuedEvent();
      SharedPreferences.setMockInitialValues({
        'analytics_queue_v1_7': jsonEncode([queued]),
      });
      final auth = AnalyticsAuth()..unlocked = false;
      final api = AnalyticsApi();
      final service = AnalyticsService.forTesting(apiFactory: (_) => api);
      addTearDown(service.background);
      addTearDown(auth.dispose);
      final binding = service.bind(auth);
      service.foreground();
      service.background();
      await binding;
      await tester.pump(const Duration(minutes: 2));
      expect(api.preferenceReads, 0);
      expect(api.batches, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('analytics_queue_v1_7')!), [queued]);

      auth.unlocked = true;
      service.foreground();
      await tester.pump();
      expect(api.preferenceReads, 1);
      expect(api.batches.length, 1);
      service.background();
      final before = prefs.getString('analytics_queue_v1_7');
      service.event('screen_view');
      await service.refreshPreferences(force: true);
      await service.flush();
      await tester.pump(const Duration(minutes: 2));
      expect(api.preferenceReads, 1);
      expect(api.batches.length, 1);
      expect(prefs.getString('analytics_queue_v1_7'), before);
      service.foreground();
      await tester.pump();
      expect(api.batches.length, 2);
      service.background();
    },
  );

  test(
    'a pre-lock preference response cannot undo opt-out or release a newer request guard',
    () async {
      final auth = AnalyticsAuth();
      final oldResponse = Completer<dynamic>();
      final newResponse = Completer<dynamic>();
      final api = AnalyticsApi();
      api.readPreference = (_) => oldResponse.future;
      api.writePreference = (_, _) => newResponse.future;
      final service = AnalyticsService.forTesting(apiFactory: (_) => api);
      addTearDown(service.background);
      addTearDown(auth.dispose);
      await service.bind(auth);
      service.foreground();
      await Future<void>.delayed(Duration.zero);
      expect(api.preferenceReads, 1);
      auth.unlocked = false;
      service.background();
      await service.setEnabled(false);
      expect(service.enabled, isFalse);
      expect(service.preferencePending, isTrue);
      expect(api.preferenceWrites, 0);

      auth.unlocked = true;
      service.foreground();
      expect(api.preferenceWrites, 1);
      oldResponse.complete({'enabled': true});
      await Future<void>.delayed(Duration.zero);
      await service.refreshPreferences(force: true);
      expect(api.preferenceWrites, 1);
      expect(service.enabled, isFalse);
      expect(service.preferencePending, isTrue);
      newResponse.complete({'enabled': false});
      await Future<void>.delayed(Duration.zero);
      expect(service.enabled, isFalse);
      expect(service.preferencePending, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('analytics_enabled_7'), isFalse);
      expect(prefs.getString('analytics_queue_v1_7'), isNull);
    },
  );

  test(
    'a previous foreground delivery cannot remove queued events or release the new delivery guard',
    () async {
      final event = queuedEvent();
      SharedPreferences.setMockInitialValues({
        'analytics_queue_v1_7': jsonEncode([event]),
      });
      final auth = AnalyticsAuth();
      final first = Completer<dynamic>(), second = Completer<dynamic>();
      final api =
          AnalyticsApi()
            ..sendEvents = (call) => call == 1 ? first.future : second.future;
      final service = AnalyticsService.forTesting(apiFactory: (_) => api);
      addTearDown(service.background);
      addTearDown(auth.dispose);
      await service.bind(auth);
      service.foreground();
      await Future<void>.delayed(Duration.zero);
      expect(api.batches.length, 1);
      service.background();
      service.foreground();
      await Future<void>.delayed(Duration.zero);
      expect(api.batches.length, 2);
      first.complete({'accepted': true});
      await Future<void>.delayed(Duration.zero);
      await service.flush();
      expect(api.batches.length, 2);
      final prefs = await SharedPreferences.getInstance();
      final queued =
          jsonDecode(prefs.getString('analytics_queue_v1_7')!) as List;
      expect(
        queued.any((item) => item['event_id'] == event['event_id']),
        isTrue,
      );
      expect(
        api.batches[1].any((item) => item['event_id'] == event['event_id']),
        isTrue,
      );
      second.complete({'accepted': true});
      await Future<void>.delayed(Duration.zero);
      expect(jsonDecode(prefs.getString('analytics_queue_v1_7')!), isEmpty);
    },
  );

  test(
    'a response from the old account cannot change the new account preference',
    () async {
      SharedPreferences.setMockInitialValues({'analytics_enabled_8': false});
      final auth = AnalyticsAuth();
      final oldResponse = Completer<dynamic>();
      final oldApi = AnalyticsApi()..readPreference = (_) => oldResponse.future;
      final newApi =
          AnalyticsApi()..readPreference = (_) async => {'enabled': false};
      final service = AnalyticsService.forTesting(
        apiFactory: (token) => token.endsWith('-7') ? oldApi : newApi,
      );
      addTearDown(service.background);
      addTearDown(auth.dispose);
      await service.bind(auth);
      service.foreground();
      await Future<void>.delayed(Duration.zero);
      auth.identity = 8;
      await service.bind(auth);
      service.foreground();
      await Future<void>.delayed(Duration.zero);
      oldResponse.complete({'enabled': true});
      await Future<void>.delayed(Duration.zero);
      expect(service.enabled, isFalse);
      expect(newApi.batches, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('analytics_enabled_8'), isFalse);
      expect(prefs.getString('analytics_queue_v1_7'), isNull);
    },
  );
}
