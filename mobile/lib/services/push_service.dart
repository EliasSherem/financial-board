import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'data_service.dart';

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

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  final StreamController<PushAction> _actionController =
      StreamController<PushAction>.broadcast();
  final List<PushAction> _pendingActions = [];
  bool _initialized = false;
  String? _lastRegisteredKey;

  Stream<PushAction> get actions => _actionController.stream;

  PushAction? consumeInitialAction() {
    if (_pendingActions.isEmpty) return null;
    return _pendingActions.removeAt(0);
  }

  Future<void> init() async {
    if (_initialized) return;

    // Initialize Firebase (requires platform setup + google-services files)
    await Firebase.initializeApp();

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Local notifications setup (for foreground messages)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _fln.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    // Android notification channel (must exist before showing notifications)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'finsight_default',
      'General Notifications',
      description: 'Default channel for general notifications',
      importance: Importance.defaultImportance,
    );
    await _fln
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // iOS permission prompt
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Android 13+ runtime permission via local notifications plugin
    await _fln
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Present alerts while app is in foreground on iOS
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Taps on background notifications
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }

    // Listen for foreground messages and show a local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      final android = notification?.android;
      if (notification != null) {
        final payload =
            message.data.isEmpty ? null : jsonEncode(message.data);
        await _fln.show(
          notification.hashCode,
          notification.title ?? 'Notification',
          notification.body ?? '',
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: android?.smallIcon ?? '@mipmap/ic_launcher',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          payload: payload,
        );
      }
    });

    // Fetch and store FCM token for backend use
    final token = await messaging.getToken();
    if (token != null) {
      await _storeToken(token);
      await _registerTokenWithBackend(token);
    }

    // Keep token in sync
    messaging.onTokenRefresh.listen((t) async {
      await _storeToken(t);
      await _registerTokenWithBackend(t);
    });

    _initialized = true;
  }

  Future<void> syncTokenWithBackend() async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('fcm_token');
    if (token == null || token.isEmpty) return;
    await _registerTokenWithBackend(token);
  }

  Future<void> _storeToken(String token) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('fcm_token', token);
    debugPrint('FCM token: $token');
  }

  Future<void> _registerTokenWithBackend(String token) async {
    final sp = await SharedPreferences.getInstance();
    final authToken = sp.getString('auth_token');
    if (authToken == null || authToken.isEmpty) return;

    final tzOffset = DateTime.now().timeZoneOffset.inMinutes;
    final tzName = DateTime.now().timeZoneName;
    final signature = '$token|$tzOffset|$tzName';
    if (_lastRegisteredKey == signature) return;

    final api = ApiClient()..setToken(authToken);
    final data = DataService(api);
    try {
      await data.registerDeviceToken(
        token: token,
        platform: _platformLabel(),
        timezoneOffsetMin: tzOffset,
        timezoneName: tzName,
      );
      _lastRegisteredKey = signature;
    } catch (e) {
      debugPrint('Failed to register device token: $e');
    }
  }

  String? _platformLabel() {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return null;
    }
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
      debugPrint('Failed to parse notification payload: $e');
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
    final idRaw =
        data['target_id'] ?? data['entity_id'] ?? data['id'];
    if (typeRaw == null || idRaw == null) return null;
    final type = typeRaw.toString().toLowerCase();
    final id = int.tryParse(idRaw.toString());
    if (type.isEmpty || id == null) return null;
    return PushAction(targetType: type, targetId: id);
  }
}
