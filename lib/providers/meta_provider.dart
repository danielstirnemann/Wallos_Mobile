import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/default_meta_data.dart';
import '../models/category.dart';
import '../models/currency.dart';
import '../models/payment_method.dart';
import '../models/household_member.dart';
import '../services/wallos_settings_service.dart';

class MetaData {
  final List<WallosCategory> categories;
  final List<WallosCurrency> currencies;
  final List<WallosPaymentMethod> paymentMethods;
  final List<WallosHouseholdMember> householdMembers;

  MetaData({
    required this.categories,
    required this.currencies,
    required this.paymentMethods,
    this.householdMembers = const [],
  });
}

final metaDataProvider = FutureProvider<MetaData>((ref) async {
  final creds = await WallosSettingsService.loadSettings();
  var url = creds.url.trim();
  final token = creds.token.trim();

  if (url.isEmpty || token.isEmpty) {
    // Keine Wallos-Verbindung konfiguriert - die App muss trotzdem
    // eigenständig nutzbar sein (z.B. "Abo hinzufügen"), daher werden hier
    // eingebaute Standard-Währungen/-Kategorien verwendet statt leerer
    // Listen.
    return MetaData(
      categories: defaultLocalCategories,
      currencies: defaultLocalCurrencies,
      paymentMethods: [],
      householdMembers: [],
    );
  }
  if (url.endsWith('/')) url = url.substring(0, url.length - 1);

  Future<List<T>> fetch<T>(String endpoint, String key, T Function(Map<String, dynamic>) fromJson) async {
    final response = await http.get(Uri.parse('$url/api/$endpoint?api_key=$token'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return (data[key] as List).map((i) => fromJson(i)).toList();
      }
    }
    return [];
  }

  final results = await Future.wait([
    fetch('categories/get_categories.php', 'categories', (j) => WallosCategory.fromJson(j)),
    fetch('currencies/get_currencies.php', 'currencies', (j) => WallosCurrency.fromJson(j)),
    fetch('payment_methods/get_payment_methods.php', 'payment_methods', (j) => WallosPaymentMethod.fromJson(j)),
    // Haushaltsmitglieder ("payer_user_id") - notwendig, da Wallos den
    // Zahler bei "add"/"edit" streng gegen die "household"-Tabelle DES
    // aktuellen Nutzers validiert. Wird kein (gültiger) Wert mitgeschickt,
    // bleibt "payer_user_id" in der DB leer/NULL, was in Wallos'
    // stats_calculations.php zu "Undefined array key"-Warnungen führt.
    fetch('household/get_household.php', 'household', (j) => WallosHouseholdMember.fromJson(j)),
  ]);

  final fetchedCategories = results[0] as List<WallosCategory>;
  final fetchedCurrencies = results[1] as List<WallosCurrency>;

  return MetaData(
    // Fallback auf die eingebauten Standardwerte, falls der Wallos-Server
    // gerade nicht erreichbar ist (z.B. Gerät offline) - damit "Abo
    // hinzufügen" auch in diesem Fall nicht blockiert bleibt.
    categories: fetchedCategories.isNotEmpty ? fetchedCategories : defaultLocalCategories,
    currencies: fetchedCurrencies.isNotEmpty ? fetchedCurrencies : defaultLocalCurrencies,
    paymentMethods: results[2] as List<WallosPaymentMethod>,
    householdMembers: results[3] as List<WallosHouseholdMember>,
  );
});
