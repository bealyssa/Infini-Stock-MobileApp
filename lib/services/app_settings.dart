import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const String _apiUrlKey = 'api_base_url';
  static const String _emailKey = 'last_email';
  static const String _themeKey = 'theme_mode';

  static final AppSettings _instance = AppSettings._internal();

  factory AppSettings() {
    return _instance;
  }

  AppSettings._internal();

  /// Get backend API URL
  Future<String> getApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiUrlKey) ?? 'http://192.168.x.x:5000/api';
  }

  /// Set backend API URL
  Future<void> setApiUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiUrlKey, url);
  }

  /// Get last used email
  Future<String?> getLastEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  /// Save last used email
  Future<void> setLastEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
  }

  /// Clear all settings (useful for logout)
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Get app info
  Map<String, String> getAppInfo() {
    return {
      'app_name': 'Infini-Stock',
      'version': '1.0.0',
      'theme': 'Dark Lavender',
      'primary_color': '#9333ea',
      'base_color': '#171717',
    };
  }
}
