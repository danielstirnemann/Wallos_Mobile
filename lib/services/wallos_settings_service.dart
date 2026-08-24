import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';

/// Service für Wallos-Einstellungen (Load/Save).
///
/// Die Werte liegen in der lokalen SQLite-Datenbank (Tabelle
/// "app_settings"), NICHT (mehr) in SharedPreferences - damit sie Teil
/// des App-Backups (siehe BackupService) sein können. Für Nutzer, die die
/// App bereits vor dieser Änderung installiert hatten, werden eventuell in
/// SharedPreferences vorhandene Werte einmalig automatisch übernommen.
class WallosSettingsService {
  static const String _keyToken = 'wallos_api_token';
  static const String _keyUrl = 'wallos_api_url';

  /// Lädt alle gespeicherten Einstellungen
  static Future<({String url, String token})> loadSettings() async {
    final db = AppDatabase();
    var url = await db.getSetting(_keyUrl);
    var token = await db.getSetting(_keyToken);

    if (url == null && token == null) {
      final migrated = await _migrateFromSharedPreferences(db);
      if (migrated != null) {
        url = migrated.url;
        token = migrated.token;
      }
    }

    return (url: url ?? '', token: token ?? '');
  }

  /// Speichert Einstellungen
  static Future<void> saveSettings({
    required String url,
    required String token,
  }) async {
    final db = AppDatabase();
    await db.setSetting(_keyUrl, url.trim());
    await db.setSetting(_keyToken, token.trim());
  }

  /// Einmalige Migration: Ältere App-Versionen speicherten URL/Token in
  /// SharedPreferences statt in der Datenbank. Damit bestehende Nutzer beim
  /// Update nicht neu einloggen müssen, werden vorhandene Werte übernommen.
  static Future<({String url, String token})?> _migrateFromSharedPreferences(AppDatabase db) async {
    final prefs = await SharedPreferences.getInstance();
    final legacyUrl = prefs.getString(_keyUrl);
    final legacyToken = prefs.getString(_keyToken);

    if (legacyUrl == null && legacyToken == null) {
      return null;
    }

    final url = legacyUrl ?? '';
    final token = legacyToken ?? '';
    await db.setSetting(_keyUrl, url);
    await db.setSetting(_keyToken, token);
    // ignore: avoid_print
    print('[WallosSettingsService] Zugangsdaten von SharedPreferences in die Datenbank migriert.');
    return (url: url, token: token);
  }
}
