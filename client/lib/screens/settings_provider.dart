// client\lib\screens\settings_provider.dart
import 'package:flutter/material.dart';

class SettingsProvider with ChangeNotifier {
  int _defaultFontSize = 12;
  String _defaultFontFamily = 'Arial';

  int get defaultFontSize => _defaultFontSize;
  String get defaultFontFamily => _defaultFontFamily;

  void updateFontSize(int newSize) {
    _defaultFontSize = newSize;
    notifyListeners(); // Thông báo cho các widget lắng nghe thay đổi
  }

  void updateFontFamily(String newFamily) {
    _defaultFontFamily = newFamily;
    notifyListeners(); // Thông báo cho các widget lắng nghe thay đổi
  }
}