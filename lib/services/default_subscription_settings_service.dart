import 'package:shared_preferences/shared_preferences.dart';

/// Standardwerte, die beim Öffnen des "Abo hinzufügen"-Dialogs initial
/// vorausgefüllt werden. Können in den Einstellungen konfiguriert werden.
class DefaultSubscriptionSettings {
  final int? currencyId;
  final int? categoryId;
  final int? paymentMethodId;

  /// Zyklus-IDs entsprechen der Wallos-API:
  /// 1=täglich, 2=wöchentlich, 3=monatlich, 4=jährlich, 5=einmalig.
  final int cycle;

  const DefaultSubscriptionSettings({
    this.currencyId,
    this.categoryId,
    this.paymentMethodId,
    this.cycle = 3, // Monatlich
  });
}

/// Lädt/speichert die Standardwerte für neue Abos (SharedPreferences).
class DefaultSubscriptionSettingsService {
  static const String _keyCurrencyId = 'default_sub_currency_id';
  static const String _keyCategoryId = 'default_sub_category_id';
  static const String _keyPaymentMethodId = 'default_sub_payment_method_id';
  static const String _keyCycle = 'default_sub_cycle';

  /// Lädt die gespeicherten Standardwerte. Nicht gesetzte Werte bleiben
  /// `null` (Zyklus fällt dabei auf "Monatlich" zurück).
  static Future<DefaultSubscriptionSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return DefaultSubscriptionSettings(
      currencyId: prefs.getInt(_keyCurrencyId),
      categoryId: prefs.getInt(_keyCategoryId),
      paymentMethodId: prefs.getInt(_keyPaymentMethodId),
      cycle: prefs.getInt(_keyCycle) ?? 3,
    );
  }

  /// Speichert die Standardwerte. `null`-Werte (z.B. "Keine Vorauswahl")
  /// werden aus den SharedPreferences entfernt.
  static Future<void> saveSettings({
    int? currencyId,
    int? categoryId,
    int? paymentMethodId,
    required int cycle,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    Future<void> setOrRemove(String key, int? value) {
      return value != null ? prefs.setInt(key, value) : prefs.remove(key);
    }

    await setOrRemove(_keyCurrencyId, currencyId);
    await setOrRemove(_keyCategoryId, categoryId);
    await setOrRemove(_keyPaymentMethodId, paymentMethodId);
    await prefs.setInt(_keyCycle, cycle);
  }
}
