import 'package:flutter/material.dart';

/// Simple theme mode holder so the UI can toggle between system/light/dark.
class ThemeService extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
  }

  void cycle() {
    if (_mode == ThemeMode.system) {
      setMode(ThemeMode.light);
    } else if (_mode == ThemeMode.light) {
      setMode(ThemeMode.dark);
    } else {
      setMode(ThemeMode.system);
    }
  }
}
