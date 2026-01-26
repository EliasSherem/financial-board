import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
    return kReleaseMode ? 'https://api.finsight.com.mx' : 'http://10.0.2.2:3001';
  }

  final String baseUrl;
  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) => Uri.parse('$baseUrl$path').replace(queryParameters: query?.map((k, v) => MapEntry(k, '$v')));

  Future<dynamic> get(String path, {Map<String, dynamic>? query, Headers? headers}) async {
    final res = await http.get(_uri(path, query), headers: _mergeHeaders(headers));
    return _decode(res);
  }

  Future<dynamic> post(String path, {Object? body, Headers? headers}) async {
    final mergedHeaders = {'Content-Type': 'application/json', ...?_mergeHeaders(headers)};
    final res = await http.post(_uri(path), body: jsonEncode(body), headers: mergedHeaders);
    final decoded = _decode(res);
    _notifyMutation(path);
    return decoded;
  }

  Future<dynamic> put(String path, {Object? body, Headers? headers}) async {
    final mergedHeaders = {'Content-Type': 'application/json', ...?_mergeHeaders(headers)};
    final res = await http.put(_uri(path), body: jsonEncode(body), headers: mergedHeaders);
    final decoded = _decode(res);
    _notifyMutation(path);
    return decoded;
  }

  Future<dynamic> delete(String path, {Headers? headers}) async {
    final res = await http.delete(_uri(path), headers: _mergeHeaders(headers));
    final decoded = _decode(res);
    _notifyMutation(path);
    return decoded;
  }

  Headers _mergeHeaders(Headers? headers) {
    final h = <String, String>{...?(headers ?? const {})};
    if (_token != null && _token!.isNotEmpty) {
      h['Authorization'] = 'Bearer $_token';
    }
    return h;
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? null : jsonDecode(res.body);
    }
    if (kDebugMode) {
      debugPrint('API error ${res.statusCode}: ${res.body}');
    }
    throw Exception('API error ${res.statusCode}');
  }

  void _notifyMutation(String path) {
    final bus = RefreshBus.instance;
    if (bus == null) return;
    bus.notifyFromPath(path);
  }
}
