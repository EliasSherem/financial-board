import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'client_context.dart';
import 'data_service.dart';
import '../state/auth_store.dart';

// Background handler must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // ignore if already initialized
  }
}

class PushAction {
  const PushAction({required this.targetType, required this.targetId});
  final String targetType;
  final int targetId;
}

@visibleForTesting
bool shouldRequestPushPermission(
  TargetPlatform platform,
  AuthorizationStatus status, {
  required bool previouslyRequested,
}) =>
    status == AuthorizationStatus.notDetermined ||
    (platform == TargetPlatform.android &&
        !previouslyRequested &&
        status == AuthorizationStatus.denied);

/// Platform boundary kept small so registration races can be tested without FCM.
abstract class PushMessagingAdapter {
  Future<void> initialize(void Function(NotificationResponse) onLocalTap);
  Stream<String> get tokenRefresh;
  Stream<RemoteMessage> get foregroundMessages;
  Stream<RemoteMessage> get openedMessages;
  Future<AuthorizationStatus> permission({bool requestIfNeeded = false});
  Future<String?> apnsToken();
  Future<String?> token();
  Future<RemoteMessage?> initialMessage();
  Future<String?> initialLocalPayload();
  Future<void> showForeground(RemoteMessage message);
}

class _FirebasePushAdapter implements PushMessagingAdapter {
  final _local = FlutterLocalNotificationsPlugin();
  static const channel = AndroidNotificationChannel(
    'finsight_default',
    'General Notifications',
    description: 'Default channel for general notifications',
    importance: Importance.defaultImportance,
  );
  FirebaseMessaging get messaging => FirebaseMessaging.instance;
  @override
  Future<void> initialize(
    void Function(NotificationResponse) onLocalTap,
  ) async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    try {
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_finsight'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: onLocalTap,
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    } catch (_) {
      // FCM registration can still recover if foreground presentation is unavailable.
      debugPrint('Foreground notification setup unavailable');
    }
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  @override
  Stream<String> get tokenRefresh => messaging.onTokenRefresh;
  @override
  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;
  @override
  Stream<RemoteMessage> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp;
  @override
  Future<AuthorizationStatus> permission({bool requestIfNeeded = false}) async {
    var settings = await messaging.getNotificationSettings();
    final preferences = await SharedPreferences.getInstance();
    // Android reports "denied" both before the first prompt and after denial.
    if (requestIfNeeded &&
        shouldRequestPushPermission(
          defaultTargetPlatform,
          settings.authorizationStatus,
          previouslyRequested:
              preferences.getBool('notification_permission_requested') ?? false,
        )) {
      settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await preferences.setBool('notification_permission_requested', true);
    }
    return settings.authorizationStatus;
  }

  @override
  Future<String?> apnsToken() => messaging.getAPNSToken();
  @override
  Future<String?> token() => messaging.getToken();
  @override
  Future<RemoteMessage?> initialMessage() => messaging.getInitialMessage();
  @override
  Future<String?> initialLocalPayload() async {
    final details = await _local.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true
        ? details?.notificationResponse?.payload
        : null;
  }

  @override
  Future<void> showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _local.show(
      notification.hashCode,
      notification.title ?? 'FinSight',
      notification.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@drawable/ic_stat_finsight',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      payload: message.data.isEmpty ? null : jsonEncode(message.data),
    );
  }
}

typedef DeviceTokenRegistrar =
    Future<void> Function(
      String authToken,
      String deviceToken,
      String? platform,
      int timezoneOffset,
      String? timezoneName,
    );
typedef DeviceTokenUnregister =
    Future<void> Function(String authToken, String deviceToken);

class PushService {
  PushService._()
    : _adapter = _FirebasePushAdapter(),
      _authProvider = (() => AuthStore.instance),
      _register = _registerDevice,
      _unregister = _unregisterDevice,
      _refreshContext = ClientContext.refresh,
      _platformOverride = null;
  @visibleForTesting
  PushService.forTesting({
    required PushMessagingAdapter adapter,
    required AuthStore? Function() auth,
    required DeviceTokenRegistrar register,
    DeviceTokenUnregister? unregister,
    TargetPlatform platform = TargetPlatform.android,
    Future<void> Function()? refreshContext,
  }) : _adapter = adapter,
       _authProvider = auth,
       _register = register,
       _unregister = unregister ?? ((_, _) async {}),
       _refreshContext = refreshContext ?? (() async {}),
       _platformOverride = platform;
  static final PushService instance = PushService._();
  final PushMessagingAdapter _adapter;
  final AuthStore? Function() _authProvider;
  final DeviceTokenRegistrar _register;
  final DeviceTokenUnregister _unregister;
  final Future<void> Function() _refreshContext;
  final TargetPlatform? _platformOverride;
  final _actionController = StreamController<PushAction>.broadcast();
  final List<PushAction> _pendingActions = [];
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Set<(String, String)> _pendingUnregister = {};
  final Map<String, Set<String>> _associatedTokens = {};
  bool _started = false, _initialized = false, _disposed = false;
  Future<void>? _initializing, _syncing;
  bool _syncRequested = false;
  String? _lastRegisteredKey, _deviceToken;
  DateTime? _lastRegisteredAt;
  int _tokenRevision = 0;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  AuthStore? _observedAuth;
  String? _observedSession;
  int? _observedUser;
  AuthorizationStatus? authorizationStatus;
  String? registrationIssue;

  TargetPlatform get _platform => _platformOverride ?? defaultTargetPlatform;
  bool get _supported =>
      !kIsWeb &&
      (_platform == TargetPlatform.android || _platform == TargetPlatform.iOS);
  Stream<PushAction> get actions => _actionController.stream;
  PushAction? consumeInitialAction() =>
      _pendingActions.isEmpty ? null : _pendingActions.removeAt(0);

  Future<void> init() {
    if (_disposed || !_supported) return Future.value();
    _started = true;
    _observeAuth();
    if (_initialized) return syncTokenWithBackend();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _deviceToken ??= preferences.getString('fcm_token');
      await _adapter.initialize(_handleNotificationResponse);
      if (_disposed) return;
      // Install token refresh before permission/APNs/token acquisition can fail.
      _subscriptions.add(
        _adapter.tokenRefresh.listen(
          _tokenChanged,
          onError: (Object _) {
            registrationIssue = 'token_unavailable';
            _scheduleRetry();
          },
        ),
      );
      _subscriptions.add(_adapter.openedMessages.listen(_handleMessageTap));
      _subscriptions.add(
        _adapter.foregroundMessages.listen((message) {
          // iOS already presents the remote alert. A second local alert duplicates it.
          if (_platform == TargetPlatform.android) {
            unawaited(_showForeground(message));
          }
        }),
      );
      _initialized = true;
      authorizationStatus = await _adapter.permission(requestIfNeeded: true);
      try {
        final initial = await _adapter.initialMessage();
        if (initial != null && !_disposed) _handleMessageTap(initial);
        final payload = await _adapter.initialLocalPayload();
        if (payload != null && !_disposed) _handlePayload(payload);
      } catch (_) {
        /* Routing can recover via the live tap stream. */
      }
      await syncTokenWithBackend();
    } catch (_) {
      registrationIssue = 'initialization_unavailable';
      debugPrint(
        'Notification initialization unavailable; will retry on foreground',
      );
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    try {
      await _adapter.showForeground(message);
    } catch (_) {
      debugPrint('Foreground notification unavailable');
    }
  }

  void _observeAuth() {
    final auth = _authProvider();
    if (identical(auth, _observedAuth)) return;
    _observedAuth?.removeListener(_authChanged);
    _observedAuth = auth;
    _observedSession = auth?.token;
    _observedUser = auth?.userId;
    _lastRegisteredKey = null;
    auth?.addListener(_authChanged);
  }

  void _authChanged() {
    final auth = _authProvider();
    if (_observedSession != auth?.token) {
      final previous = _observedSession;
      if (previous != null) {
        final tokens = _associatedTokens.remove(previous) ?? <String>{};
        if (_deviceToken != null) tokens.add(_deviceToken!);
        if (auth?.token == null || auth?.userId != _observedUser) {
          for (final token in tokens) {
            _pendingUnregister.add((previous, token));
          }
        } else if (auth?.token != null) {
          (_associatedTokens[auth!.token!] ??= {}).addAll(tokens);
        }
      }
      _observedSession = auth?.token;
      _observedUser = auth?.userId;
      _lastRegisteredKey = null;
      _pendingActions.clear();
    }
    if (auth?.isAuthenticated == true || _pendingUnregister.isNotEmpty) {
      unawaited(syncTokenWithBackend());
    } else {
      _retryTimer?.cancel();
      _retryTimer = null;
    }
  }

  void _tokenChanged(String token) {
    if (_disposed || token.isEmpty) return;
    final session = _authProvider()?.token;
    if (_deviceToken != null && _deviceToken != token && session != null) {
      (_associatedTokens[session] ??= {}).add(_deviceToken!);
      if (_authProvider()?.isAuthenticated == true) {
        _pendingUnregister.add((session, _deviceToken!));
      }
    }
    _tokenRevision++;
    _deviceToken = token;
    unawaited(syncTokenWithBackend());
  }

  Future<void> syncTokenWithBackend() async {
    // Auth restoration can run before startup services. Do not prompt from login
    // or from a locked session; explicit startup owns initialization.
    if (_disposed || !_started || !_supported) return;
    _observeAuth();
    if (_authProvider()?.isAuthenticated != true &&
        _pendingUnregister.isEmpty) {
      return;
    }
    _retryAttempt = 0;
    _retryTimer?.cancel();
    _retryTimer = null;
    if (!_initialized) {
      await init();
      return;
    }
    await _queueSync();
  }

  Future<void> _queueSync() {
    if (_syncing != null) {
      _syncRequested = true;
      return _syncing!;
    }
    final completion = Completer<void>();
    _syncing = completion.future;
    unawaited(() async {
      try {
        do {
          _syncRequested = false;
          await _synchronizeToken();
        } while (_syncRequested && !_disposed);
      } finally {
        _syncing = null;
        completion.complete();
      }
    }());
    return completion.future;
  }

  bool _matches(AuthStore auth, String token) =>
      !_disposed &&
      identical(auth, _authProvider()) &&
      auth.isAuthenticated &&
      auth.token == token;
  Future<void> _synchronizeToken() async {
    for (final pending in _pendingUnregister.toList()) {
      if (_disposed) return;
      try {
        await _unregister(pending.$1, pending.$2);
        _pendingUnregister.remove(pending);
        _associatedTokens[pending.$1]?.remove(pending.$2);
      } catch (_) {
        registrationIssue = 'unregister_unavailable';
        _scheduleRetry();
        break;
      }
    }
    final auth = _authProvider();
    if (_disposed || auth?.isAuthenticated != true) return;
    final session = auth!.token!;
    try {
      authorizationStatus = await _adapter.permission();
      if (!_matches(auth, session)) return;
      if (authorizationStatus == AuthorizationStatus.denied ||
          authorizationStatus == AuthorizationStatus.notDetermined) {
        registrationIssue = 'permission_denied';
        return;
      }
      if (_platform == TargetPlatform.iOS &&
          await _adapter.apnsToken() == null) {
        registrationIssue = 'apns_pending';
        _scheduleRetry();
        return;
      }
      if (!_matches(auth, session)) return;
      final revision = _tokenRevision;
      final fetched = await _adapter.token();
      if (!_matches(auth, session)) return;
      if (revision == _tokenRevision && (fetched == null || fetched.isEmpty)) {
        registrationIssue = 'token_unavailable';
        _scheduleRetry();
        return;
      }
      if (revision == _tokenRevision && fetched != null && fetched.isNotEmpty) {
        if (_deviceToken != null && _deviceToken != fetched) {
          _pendingUnregister.add((session, _deviceToken!));
          _syncRequested = true;
        }
        _deviceToken = fetched;
      }
      final token = _deviceToken;
      if (token == null || token.isEmpty) {
        registrationIssue = 'token_unavailable';
        _scheduleRetry();
        return;
      }
      for (final previous in _associatedTokens[session] ?? <String>{}) {
        if (previous != token && _pendingUnregister.add((session, previous))) {
          _syncRequested = true;
        }
      }
      final preferences = await SharedPreferences.getInstance();
      if (!_matches(auth, session)) return;
      await preferences.setString('fcm_token', token);
      await _refreshContext().timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
      if (!_matches(auth, session)) return;
      final offset = DateTime.now().timeZoneOffset.inMinutes;
      final signature = '$session|$token|$offset|${ClientContext.timezone}';
      if (_lastRegisteredKey == signature &&
          _lastRegisteredAt != null &&
          DateTime.now().difference(_lastRegisteredAt!) <
              const Duration(hours: 12)) {
        if (_pendingUnregister.isEmpty) registrationIssue = null;
        return;
      }
      (_associatedTokens[session] ??= {}).add(token);
      await _register(
        session,
        token,
        _platformLabel(),
        offset,
        ClientContext.timezone,
      );
      if (!_matches(auth, session) || token != _deviceToken) return;
      _lastRegisteredKey = signature;
      _lastRegisteredAt = DateTime.now();
      registrationIssue = null;
      _retryAttempt = 0;
      if (_pendingUnregister.isEmpty) {
        _retryTimer?.cancel();
        _retryTimer = null;
      }
    } catch (_) {
      if (_matches(auth, session)) {
        registrationIssue = 'registration_unavailable';
        _scheduleRetry();
      }
    }
  }

  void _scheduleRetry() {
    if (_disposed ||
        _retryTimer != null ||
        (_authProvider()?.isAuthenticated != true &&
            _pendingUnregister.isEmpty) ||
        _retryAttempt >= 3) {
      return;
    }
    final delay = [2, 5, 15][_retryAttempt++];
    _retryTimer = Timer(Duration(seconds: delay), () {
      _retryTimer = null;
      if (!_disposed &&
          _initialized &&
          (_authProvider()?.isAuthenticated == true ||
              _pendingUnregister.isNotEmpty)) {
        unawaited(_queueSync());
      }
    });
  }

  static Future<void> _registerDevice(
    String session,
    String token,
    String? platform,
    int offset,
    String? zone,
  ) async {
    final api = ApiClient()..setToken(session);
    await DataService(api).registerDeviceToken(
      token: token,
      platform: platform,
      timezoneOffsetMin: offset,
      timezoneName: zone,
    );
  }

  static Future<void> _unregisterDevice(String session, String token) async {
    final api = ApiClient()..setToken(session);
    await api.post('/api/device-tokens/unregister', body: {'token': token});
  }

  String? _platformLabel() => switch (_platform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => null,
  };
  void _handlePayload(String payload) {
    try {
      final value = jsonDecode(payload);
      if (value is Map<String, dynamic>) {
        final action = _actionFromData(value);
        if (action != null) _emitAction(action);
      }
    } catch (_) {
      debugPrint('Invalid notification payload');
    }
  }

  @visibleForTesting
  Future<void> dispose() async {
    _disposed = true;
    _retryTimer?.cancel();
    _observedAuth?.removeListener(_authChanged);
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _actionController.close();
  }

  void _handleMessageTap(RemoteMessage message) {
    final action = _actionFromData(message.data);
    if (action != null) {
      _emitAction(action);
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final action = _actionFromData(data);
      if (action != null) {
        _emitAction(action);
      }
    } catch (e) {
      debugPrint('Invalid notification payload');
    }
  }

  void _emitAction(PushAction action) {
    if (_actionController.hasListener) {
      _actionController.add(action);
    } else {
      _pendingActions.add(action);
    }
  }

  PushAction? _actionFromData(Map<String, dynamic> data) {
    if (data.isEmpty) return null;
    final typeRaw =
        data['target_type'] ?? data['type'] ?? data['kind'] ?? data['action'];
    final idRaw = data['target_id'] ?? data['entity_id'] ?? data['id'];
    if (const {
      'momentum',
      'momentum_week_ready',
      'momentum_week_reminder',
      'momentum_comeback',
    }.contains(typeRaw?.toString().toLowerCase())) {
      return const PushAction(targetType: 'momentum', targetId: 0);
    }
    if (typeRaw == null || idRaw == null) return null;
    final type = typeRaw.toString().toLowerCase();
    final id = int.tryParse(idRaw.toString());
    if (type.isEmpty || id == null) return null;
    return PushAction(targetType: type, targetId: id);
  }
}
