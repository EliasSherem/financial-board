import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../state/refresh_bus.dart';
import 'analytics_service.dart';
import '../state/auth_store.dart';

typedef Headers = Map<String, String>;

class ApiException implements Exception {
  const ApiException(
    this.statusCode,
    this.message, {
    this.code,
    this.reason,
    this.retryAfterSeconds,
  });
  final int statusCode;
  final String message;
  final String? code;
  final String? reason;
  final int? retryAfterSeconds;
  @override
  String toString() => message;
}

/// Simple API client stub. Replace endpoints to match your server.
class ApiClient {
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? _resolveBaseUrl();

  // In release builds default to production Cloud Run API.
  // In debug, prefer Android emulator loopback; override anytime with --dart-define API_BASE_URL=...
  static String _resolveBaseUrl() {
    final env = const String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (env.isNotEmpty) return env;
    if (kReleaseMode) return 'https://api.finsight.com.mx';
    if (kIsWeb) return 'http://localhost:3001';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:3001',
      _ => 'http://127.0.0.1:3001',
    };
  }

  final String baseUrl;
  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) => Uri.parse(
    '$baseUrl$path',
  ).replace(queryParameters: query?.map((k, v) => MapEntry(k, '$v')));

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Headers? headers,
    Duration? timeout,
  }) async {
    final requestToken = _token;
    final res = await _send(
      requestToken,
      () => http.get(
        _uri(path, query),
        headers: _mergeHeaders(headers, requestToken),
      ),
      timeout: timeout,
    );
    return _decode(res, requestToken);
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Headers? headers,
    Duration? timeout,
  }) async {
    final requestToken = _token;
    final mergedHeaders = {
      'Content-Type': 'application/json',
      ..._mergeHeaders(headers, requestToken),
    };
    final res = await _send(
      requestToken,
      () =>
          http.post(_uri(path), body: jsonEncode(body), headers: mergedHeaders),
      timeout: timeout,
    );
    final decoded = _decode(res, requestToken);
    _notifyMutation(path);
    return decoded;
  }

  Future<dynamic> put(String path, {Object? body, Headers? headers}) async {
    final requestToken = _token;
    final mergedHeaders = {
      'Content-Type': 'application/json',
      ..._mergeHeaders(headers, requestToken),
    };
    final res = await _send(
      requestToken,
      () =>
          http.put(_uri(path), body: jsonEncode(body), headers: mergedHeaders),
    );
    final decoded = _decode(res, requestToken);
    _notifyMutation(path);
    return decoded;
  }

  Future<dynamic> patch(String path, {Object? body, Headers? headers}) async {
    final requestToken = _token;
    final mergedHeaders = {
      'Content-Type': 'application/json',
      ..._mergeHeaders(headers, requestToken),
    };
    final res = await _send(
      requestToken,
      () => http.patch(
        _uri(path),
        body: jsonEncode(body),
        headers: mergedHeaders,
      ),
    );
    final decoded = _decode(res, requestToken);
    _notifyMutation(path);
    return decoded;
  }

  Future<dynamic> uploadFile(
    String path, {
    required File file,
    required String fieldName,
    Headers? headers,
    Duration timeout = const Duration(seconds: 90),
    Set<int> allowedErrorStatusCodes = const {},
  }) async {
    final requestToken = _token;
    try {
      final request = http.MultipartRequest('POST', _uri(path));
      request.headers.addAll(_mergeHeaders(headers, requestToken));
      request.files.add(
        await http.MultipartFile.fromPath(
          fieldName,
          file.path,
          contentType: _mediaTypeForPath(file.path),
        ),
      );
      _assertSessionUnlocked(requestToken);
      final streamed = await request.send().timeout(timeout);
      final res = await http.Response.fromStream(streamed);
      if (allowedErrorStatusCodes.contains(res.statusCode)) {
        final decoded = res.body.isEmpty ? null : jsonDecode(res.body);
        _notifyMutation(path);
        return decoded;
      }
      final decoded = _decode(res, requestToken);
      _notifyMutation(path);
      return decoded;
    } on TimeoutException {
      throw Exception(
        'Unable to connect to ${_hostLabel()}. The upload timed out.',
      );
    } on http.ClientException catch (e) {
      throw Exception(_transportMessage(e.toString()));
    } catch (e) {
      final raw = e.toString();
      if (_looksLikeTransportError(raw)) {
        throw Exception(_transportMessage(raw));
      }
      rethrow;
    }
  }

  Future<dynamic> delete(String path, {Headers? headers}) async {
    final requestToken = _token;
    final res = await _send(
      requestToken,
      () => http.delete(
        _uri(path),
        headers: _mergeHeaders(headers, requestToken),
      ),
    );
    final decoded = _decode(res, requestToken);
    _notifyMutation(path);
    return decoded;
  }

  Headers _mergeHeaders(Headers? headers, String? requestToken) {
    final h = <String, String>{...(headers ?? const {})};
    if (requestToken != null && requestToken.isNotEmpty) {
      h['Authorization'] = 'Bearer $requestToken';
    }
    return h;
  }

  MediaType _mediaTypeForPath(String path) {
    final filename = path.split(RegExp(r'[/\\]')).last.toLowerCase();
    if (filename.endsWith('.jpg') || filename.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (filename.endsWith('.png')) return MediaType('image', 'png');
    if (filename.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('application', 'octet-stream');
  }

  Future<http.Response> _send(
    String? requestToken,
    Future<http.Response> Function() request, {
    Duration? timeout,
  }) async {
    _assertSessionUnlocked(requestToken);
    try {
      return await request().timeout(timeout ?? const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception(
        'Unable to connect to ${_hostLabel()}. The request timed out.',
      );
    } on http.ClientException catch (e) {
      throw Exception(_transportMessage(e.toString()));
    } catch (e) {
      final raw = e.toString();
      if (_looksLikeTransportError(raw)) {
        throw Exception(_transportMessage(raw));
      }
      rethrow;
    }
  }

  void _assertSessionUnlocked(String? requestToken) {
    final auth = AuthStore.instance;
    if (requestToken != null && auth?.token == requestToken && auth!.isLocked) {
      throw const ApiException(
        423,
        'Unlock the app to continue.',
        code: 'SESSION_LOCKED',
      );
    }
  }

  dynamic _decode(http.Response res, String? requestToken) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? null : jsonDecode(res.body);
    }
    String? message;
    String? code;
    String? reason;
    int? retryAfterSeconds;
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          code = decoded['code'] as String?;
          reason = decoded['reason'] as String?;
          retryAfterSeconds = (decoded['retry_after_seconds'] as num?)?.toInt();
          final candidate = decoded['message'] ?? decoded['error'];
          if (candidate is String && candidate.trim().isNotEmpty) {
            message = candidate.trim();
          }
        }
      } catch (_) {
        final text = res.body.trim();
        if (text.isNotEmpty) {
          message = text;
        }
      }
    }
    if (res.statusCode == 401 && requestToken != null) {
      unawaited(
        AuthStore.instance?.invalidateToken(requestToken) ??
            Future<void>.value(),
      );
    }
    // Authentication/reset and billing responses must never reach debug logs.
    throw ApiException(
      res.statusCode,
      message ?? 'API error ${res.statusCode}',
      code: code,
      reason: reason,
      retryAfterSeconds: retryAfterSeconds,
    );
  }

  void _notifyMutation(String path) {
    final segments = Uri.tryParse(path)?.pathSegments ?? const <String>[];
    if (segments.length >= 2 && segments.first == 'api') {
      const mapping = {
        'accounts': 'accounts',
        'transactions': 'transactions',
        'categories': 'categories',
        'subcategories': 'categories',
        'payments': 'payments',
        'projects': 'projects',
        'invoices': 'invoices',
        'investments': 'investments',
        'receipts': 'receipt',
      };
      final feature = mapping[segments[1]];
      if (feature != null) {
        AnalyticsService.instance.event('feature_used', feature: feature);
      }
    }
    final bus = RefreshBus.instance;
    if (bus == null) return;
    bus.notifyFromPath(path);
  }

  bool _looksLikeTransportError(String raw) {
    return raw.contains('SocketException') ||
        raw.contains('Failed host lookup') ||
        raw.contains('Connection refused') ||
        raw.contains('Connection reset by peer') ||
        raw.contains('Network is unreachable');
  }

  String _transportMessage(String raw) {
    final host = _hostLabel();
    if (raw.contains('Failed host lookup')) {
      return 'Unable to find $host. Check your internet connection or DNS settings.';
    }
    if (raw.contains('Connection refused')) {
      return 'Unable to connect to $host. The server refused the connection.';
    }
    if (raw.contains('Connection reset by peer')) {
      return 'Connection to $host was interrupted. Please try again.';
    }
    if (raw.contains('Network is unreachable')) {
      return 'Unable to reach $host. Check your internet connection and try again.';
    }
    return 'Unable to connect to $host. Check your internet connection and try again.';
  }

  String _hostLabel() {
    try {
      final host = Uri.parse(baseUrl).host;
      return host.isEmpty ? baseUrl : host;
    } catch (_) {
      return baseUrl;
    }
  }
}
