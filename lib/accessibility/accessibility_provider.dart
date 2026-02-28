import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'accessibility_theme.dart';
// Note: We'll inject or reference AccessibilityVoice below if needed, or handle it separately.

class AccessibilityProvider extends ChangeNotifier {
  // Shared Preferences Keys
  static const String _themeKey = 'accessibility_theme';
  static const String _fontScaleKey = 'accessibility_font_scale';
  static const String _voiceGuideKey = 'accessibility_voice_guide';
  static const String _talkToAppKey = 'accessibility_talk_to_app';

  AccessibilityThemeType _themeType = AccessibilityThemeType.standardDark;
  double _fontScale = 1.0;
  bool _voiceGuideEnabled = false;
  bool _talkToAppEnabled = false;
  bool _isTourRunning = false;

  AccessibilityProvider() {
    _loadSettings();
  }

  // --- Getters ---
  AccessibilityThemeType get themeType => _themeType;
  double get fontScale => _fontScale;
  bool get voiceGuideEnabled => _voiceGuideEnabled;
  bool get talkToAppEnabled => _talkToAppEnabled;
  bool get isTourRunning => _isTourRunning;
  ThemeData get themeData => AccessibilityTheme.getTheme(_themeType);
  ColorFilter? get colorFilter => AccessibilityTheme.getColorFilter(_themeType);

  // --- Load Settings ---
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Theme
    final themeIndex = prefs.getInt(_themeKey) ?? AccessibilityThemeType.standardDark.index;
    if (themeIndex >= 0 && themeIndex < AccessibilityThemeType.values.length) {
      _themeType = AccessibilityThemeType.values[themeIndex];
    }
    
    // Font Scale
    _fontScale = prefs.getDouble(_fontScaleKey) ?? 1.0;
    
    // Voice Guide
    _voiceGuideEnabled = prefs.getBool(_voiceGuideKey) ?? false;
    
    // Talk to App
    _talkToAppEnabled = prefs.getBool(_talkToAppKey) ?? false;

    notifyListeners();
  }

  // --- Setters ---
  Future<void> setTheme(AccessibilityThemeType type) async {
    if (_themeType == type) return;
    _themeType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, _themeType.index);
    notifyListeners();
  }

  Future<void> setFontScale(double scale) async {
    if (_fontScale == scale) return;
    // Cap font scale to prevent completely breaking layouts
    _fontScale = scale.clamp(1.0, 2.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontScaleKey, _fontScale);
    notifyListeners();
  }

  Future<void> setVoiceGuideEnabled(bool enabled) async {
    if (_voiceGuideEnabled == enabled) return;
    _voiceGuideEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_voiceGuideKey, _voiceGuideEnabled);
    notifyListeners();
  }

  Future<void> setTalkToAppEnabled(bool enabled) async {
    if (_talkToAppEnabled == enabled) return;
    _talkToAppEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_talkToAppKey, _talkToAppEnabled);
    notifyListeners();
  }

  void setTourRunning(bool running) {
    if (_isTourRunning == running) return;
    _isTourRunning = running;
    notifyListeners();
  }
}
