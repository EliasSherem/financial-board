import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/widget_service.dart';

class ThemeModeStore extends ChangeNotifier {
  static const _key = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _mode = _parse(sp.getString(_key));
    } catch (_) {
      _mode = ThemeMode.system;
    }
    unawaited(NativeWidgetBridge.updateThemeMode(_mode));
    notifyListeners();
  }

  Future<void> setMode(ThemeMode value) async {
    _mode = value;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_key, _serialize(value));
    } catch (_) {}
    unawaited(NativeWidgetBridge.updateThemeMode(value));
    notifyListeners();
  }

  static ThemeMode _parse(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static String _serialize(ThemeMode value) {
    return switch (value) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}
