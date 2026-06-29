import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  String _defaultQuality = 'Highest Available';
  bool _wifiOnly = false;
  bool _subtitleDownload = false;

  final Completer<void> _loadCompleter = Completer<void>();

  ThemeMode get themeMode => _themeMode;
  String get defaultQuality => _defaultQuality;
  bool get wifiOnly => _wifiOnly;
  bool get subtitleDownload => _subtitleDownload;

  /// Await this in main() to ensure settings are loaded before the first frame
  Future<void> waitForLoad() => _loadCompleter.future;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  ThemeProvider() {
    _loadSettings();
  }

  Future<File> get _settingsFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/app_settings.json');
  }

  Future<void> _loadSettings() async {
    try {
      final file = await _settingsFile;
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        
        // Theme
        final themeStr = data['themeMode'] as String?;
        if (themeStr == 'system') _themeMode = ThemeMode.system;
        if (themeStr == 'light') _themeMode = ThemeMode.light;
        if (themeStr == 'dark') _themeMode = ThemeMode.dark;

        // Quality
        _defaultQuality = data['defaultQuality'] as String? ?? '1080p';

        _wifiOnly = data['wifiOnly'] as bool? ?? false;
        _subtitleDownload = data['subtitleDownload'] as bool? ?? false;

        notifyListeners();
      }
    } catch (e) {
      // Ignore load errors
    } finally {
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    }
  }

  Future<void> _saveSettings() async {
    try {
      final file = await _settingsFile;
      final themeStr = _themeMode == ThemeMode.system
          ? 'system'
          : (_themeMode == ThemeMode.light ? 'light' : 'dark');
          
      final data = {
        'themeMode': themeStr,
        'defaultQuality': _defaultQuality,
        'wifiOnly': _wifiOnly,
        'subtitleDownload': _subtitleDownload,
      };
      
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      // Ignore save errors
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _saveSettings();
    notifyListeners();
  }

  void setDefaultQuality(String quality) {
    if (_defaultQuality == quality) return;
    _defaultQuality = quality;
    _saveSettings();
    notifyListeners();
  }


  void setWifiOnly(bool value) {
    if (_wifiOnly == value) return;
    _wifiOnly = value;
    _saveSettings();
    notifyListeners();
  }

  void setSubtitleDownload(bool value) {
    if (_subtitleDownload == value) return;
    _subtitleDownload = value;
    _saveSettings();
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _saveSettings();
    notifyListeners();
  }
}
