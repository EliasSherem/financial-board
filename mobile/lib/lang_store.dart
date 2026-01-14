import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LangStore extends ChangeNotifier {
  String _lang = 'en';
  String get lang => _lang;
  Locale get locale => Locale(_lang);

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _lang = sp.getString('lang') ?? 'en';
    } catch (_) {
      _lang = 'en';
    }
    notifyListeners();
  }

  Future<void> setLang(String value) async {
    _lang = (value == 'es') ? 'es' : 'en';
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('lang', _lang);
    } catch (_) {}
    notifyListeners();
  }
}

