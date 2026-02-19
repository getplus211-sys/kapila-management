import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDark = true;
  static const _key = 'app_theme_dark';

  bool get isDark => _isDark;

  ThemeProvider() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_key) ?? true;
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isDark);
  }

  static const _dBg       = Color(0xFF0B0E1A);
  static const _dSurface  = Color(0xFF141828);
  static const _dSurface2 = Color(0xFF1C2035);
  static const _dBrand    = Color(0xFF7B4FD6);
  static const _dAccent   = Color(0xFF9B6FF0);
  static const _dText1    = Color(0xFFEEEEF5);
  static const _dText2    = Color(0xFF8890AA);
  static const _dBorder   = Color(0xFF252A40);

  static const _lBg       = Color(0xFFEEF0FF);
  static const _lSurface  = Color(0xFFFFFFFF);
  static const _lSurface2 = Color(0xFFF0F2FF);
  static const _lBrand    = Color(0xFF7B4FD6);
  static const _lAccent   = Color(0xFF6B3FC6);
  static const _lText1    = Color(0xFF1A1A2E);
  static const _lText2    = Color(0xFF6B7280);
  static const _lBorder   = Color(0xFFDDE0F5);

  Color get bg       => _isDark ? _dBg       : _lBg;
  Color get surface  => _isDark ? _dSurface  : _lSurface;
  Color get surface2 => _isDark ? _dSurface2 : _lSurface2;
  Color get brand    => _isDark ? _dBrand    : _lBrand;
  Color get accent   => _isDark ? _dAccent   : _lAccent;
  Color get text1    => _isDark ? _dText1    : _lText1;
  Color get text2    => _isDark ? _dText2    : _lText2;
  Color get border   => _isDark ? _dBorder   : _lBorder;

  Color get glassBg     => _isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.65);
  Color get glassBorder => _isDark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.80);
  List<Color> get bgGradient => _isDark
      ? [const Color(0xFF0B0E1A), const Color(0xFF1C2035)]
      : [const Color(0xFFEEF0FF), const Color(0xFFE0E4FF)];
}