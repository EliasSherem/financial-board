import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

String clientEventId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class ClientContext {
  static const _channel = MethodChannel('com.finsight/client_context');
  static String? timezone;
  static String appVersion = const String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'unknown',
  );
  static String build = const String.fromEnvironment(
    'APP_BUILD',
    defaultValue: 'unknown',
  );
  static String get platform =>
      kIsWeb
          ? 'web'
          : switch (defaultTargetPlatform) {
            TargetPlatform.android => 'android',
            TargetPlatform.iOS => 'ios',
            _ => 'unknown',
          };
  static Future<void> refresh() async {
    if (platform != 'android' && platform != 'ios') return;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('read');
      final zone = result?['timezone'] as String?;
      if (zone != null && zone.length <= 100) timezone = zone;
      appVersion = result?['app_version'] as String? ?? appVersion;
      build = result?['build'] as String? ?? build;
    } on PlatformException {
      /* Offset is a documented fallback. */
    } on MissingPluginException {
      /* Widget tests and unsupported surfaces. */
    }
  }
}
