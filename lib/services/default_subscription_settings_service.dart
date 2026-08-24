import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';

/// Standardwerte, die beim Öffnen des "Abo hinzufügen"-Dialogs initial
/// vorausgefüllt werden. Können in den Einstellungen konfiguriert werden.
class DefaultSubscriptionSettings {
  final int? currencyId;
  final int? categoryId;
  final int? paymentMethodId;
  final int? payerUserId;

  /// Zyklus-IDs entsprechen der Wallos-API:
  /// 1=täglich, 2=wöchentlich, 3=monatlich, 4=jährlich, 5=einmalig.
  final int cycle;

  const DefaultSubscriptionSettings({
    this.currencyId,
    this.categoryId,
    this.paymentMethodId,
    this.payerUserId,
    this.cycle = 3, // Monatlich
  });
}

/// Lädt/speichert die Standardwerte für neue Abos.
///
/// Die Werte liegen in der lokalen SQLite-Datenbank (Tabelle
/// "app_settings"), NICHT (mehr) in SharedPreferences - damit sie Teil
/// des App-Backups (siehe BackupService) sein können. Für Nutzer, die die
/// App bereits vor dieser Änderung installiert hatten, werden eventuell in
/// SharedPreferences vorhandene Werte einmalig automatisch übernommen.
class DefaultSubscriptionSettingsService {
  static const String _keyCurrencyId = 'default_sub_currency_id';
  static const String _keyCategoryId = 'default_sub_category_id';
  static const String _keyPaymentMethodId = 'default_sub_payment_method_id';
  static const String _keyPayerUserId = 'default_sub_payer_user_id';
  static const String _keyCycle = 'default_sub_cycle';

  static const List<String> _allKeys = [
    _keyCurrencyId,
    _keyCategoryId,
    _keyPaymentMethodId,
    _keyPayerUserId,
    _keyCycle,
  ];

  /// Lädt die gespeicherten Standardwerte. Nicht gesetzte Werte bleiben
  /// `null` (Zyklus fällt dabei auf "Monatlich" zurück).
  static Future<DefaultSubscriptionSettings> loadSettings() async {
    final db = AppDatabase();
    var all = await db.getAllSettings();

    if (_allKeys.every((key) => !all.containsKey(key))) {
      final migrated = await _migrateFromSharedPreferences(db);
      if (migrated.isNotEmpty) {
        all = migrated;
      }
    }

    int? parseIntOrNull(String? s) => s == null ? null : int.tryParse(s);

    return DefaultSubscriptionSettings(
      currencyId: parseIntOrNull(all[_keyCurrencyId]),
      categoryId: parseIntOrNull(all[_keyCategoryId]),
      paymentMethodId: parseIntOrNull(all[_keyPaymentMethodId]),
      payerUserId: parseIntOrNull(all[_keyPayerUserId]),
      cycle: parseIntOrNull(all[_keyCycle]) ?? 3,
    );
  }

  /// Speichert die Standardwerte. `null`-Werte (z.B. "Keine Vorauswahl")
  /// werden entfernt.
  static Future<void> saveSettings({
    int? currencyId,
    int? categoryId,
    int? paymentMethodId,
    int? payerUserId,
    required int cycle,
  }) async {
    final db = AppDatabase();

    Future<void> setOrRemove(String key, int? value) {
      return db.setSetting(key, value?.toString());
    }

    await setOrRemove(_keyCurrencyId, currencyId);
    await setOrRemove(_keyCategoryId, categoryId);
    await setOrRemove(_keyPaymentMethodId, paymentMethodId);
    await setOrRemove(_keyPayerUserId, payerUserId);
    await db.setSetting(_keyCycle, cycle.toString());
  }

  /// Einmalige Migration von \u00e4lteren App-Versionen, die diese Werte noch
  /// in SharedPreferences (als Int) abgelegt hatten.
  static Future<Map<String, String>> _migrateFromSharedPreferences(AppDatabase db) async {
    final prefs = await SharedPreferences.getInstance();
    final migrated = <String, String>{};

    for (final key in _allKeys) {
      final value = prefs.getInt(key);
      if (value != null) {
        migrated[key] = value.toString();
      }
    }

    if (migrated.isNotEmpty) {
      for (final entry in migrated.entries) {
        await db.setSetting(entry.key, entry.value);
      }
      // ignore: avoid_print
      print('[DefaultSubscriptionSettingsService] Standardwerte von SharedPreferences in die Datenbank migriert.');
    }

    return migrated;
  }
}
