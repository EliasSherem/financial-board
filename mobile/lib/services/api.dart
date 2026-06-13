import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../state/refresh_bus.dart';

typedef Headers = Map<String, String>;

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
  }) async {
    final res = await _send(
      () => http.get(_uri(path, query), headers: _mergeHeaders(headers)),
    );
    return _decode(res);
  }

  Future<dynamic> post(String path, {Object? body, Headers? headers}) async {
    final mergedHeaders = {
      'Content-Type': 'application/json',
      ..._mergeHeaders(headers),
    };
    final res = await _send(
      () =>
          http.post(_uri(path), body: jsonEncode(body), headers: mergedHeaders),
    );
    final decoded = _decode(res);
    _notifyMutation(path);
    return decoded;
  }

  Future<dynamic> put(String path, {Object? body, Headers? headers}) async {
    final mergedHeaders = {
      'Content-Type': 'application/json',
      ..._mergeHeaders(headers),
    };
    final res = await _send(
      () =>
          http.put(_uri(path), body: jsonEncode(body), headers: mergedHeaders),
    );
    final decoded = _decode(res);
    _notifyMutation(path);
    return decoded;
  }

  Future<dynamic> patch(String path, {Object? body, Headers? headers}) async {
    final mergedHeaders = {
      'Content-Type': 'application/json',
      ..._mergeHeaders(headers),
    };
    final res = await _send(
      () => http.patch(
        _uri(path),
        body: jsonEncode(body),
        headers: mergedHeaders,
      ),
    );
    final decoded = _decode(res);
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
    try {
      final request = http.MultipartRequest('POST', _uri(path));
      request.headers.addAll(_mergeHeaders(headers));
      request.files.add(
        await http.MultipartFile.fromPath(
          fieldName,
          file.path,
          contentType: _mediaTypeForPath(file.path),
        ),
      );
      final streamed = await request.send().timeout(timeout);
      final res = await http.Response.fromStream(streamed);
      if (allowedErrorStatusCodes.contains(res.statusCode)) {
        final decoded = res.body.isEmpty ? null : jsonDecode(res.body);
        _notifyMutation(path);
        return decoded;
      }
      final decoded = _decode(res);
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
    final res = await _send(
      () => http.delete(_uri(path), headers: _mergeHeaders(headers)),
    );
    final decoded = _decode(res);
    _notifyMutation(path);
    return decoded;
  }

  Headers _mergeHeaders(Headers? headers) {
    final h = <String, String>{...(headers ?? const {})};
    if (_token != null && _token!.isNotEmpty) {
      h['Authorization'] = 'Bearer $_token';
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

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(const Duration(seconds: 15));
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

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? null : jsonDecode(res.body);
    }
    String? message;
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
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
    if (kDebugMode) {
      debugPrint('API error ${res.statusCode}: ${res.body}');
    }
    throw Exception(message ?? 'API error ${res.statusCode}');
  }

  void _notifyMutation(String path) {
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
