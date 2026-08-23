import 'package:shared_preferences/shared_preferences.dart';

/// Service für Wallos-Einstellungen (Load/Save)
class WallosSettingsService {
  static const String _keyToken = 'wallos_api_token';
  static const String _keyUrl = 'wallos_api_url';

  /// Lädt alle gespeicherten Einstellungen
  static Future<({String url, String token})> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      url: prefs.getString(_keyUrl) ?? '',
      token: prefs.getString(_keyToken) ?? '',
    );
  }

  /// Speichert Einstellungen
  static Future<void> saveSettings({
    required String url,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUrl, url.trim());
    await prefs.setString(_keyToken, token.trim());
  }
}
