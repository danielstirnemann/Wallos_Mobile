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

  // WICHTIG: Ein HTTP-Fehler oder "success: false" wird hier bewusst als
  // Exception weitergereicht (statt still eine leere Liste zurückzugeben) -
  // nur so löst ein ECHTER Verbindungs-/API-Fehler unten den Fallback auf
  // die lokalen Standardwerte aus. Eine vom Server tatsächlich zurückgegebene
  // LEERE Liste (z.B. Nutzer hat noch keine eigenen Kategorien) bleibt
  // dagegen unangetastet leer - siehe Kommentar unten.
  Future<List<T>> fetch<T>(String endpoint, String key, T Function(Map<String, dynamic>) fromJson) async {
    final response = await http.get(Uri.parse('$url/api/$endpoint?api_key=$token'));
    if (response.statusCode != 200) {
      throw Exception('$endpoint: HTTP ${response.statusCode}');
    }
    final data = json.decode(response.body);
    if (data['success'] != true) {
      throw Exception('$endpoint: ${data['title'] ?? 'API meldete success=false'}');
    }
    return (data[key] as List).map((i) => fromJson(i)).toList();
  }

  // WICHTIG: Die eingebauten lokalen Standardwerte (negative IDs) dürfen NUR
  // verwendet werden, wenn der Wallos-Server tatsächlich NICHT erreichbar
  // ist (z.B. offline) - NICHT einfach, weil die echte Liste zufällig leer
  // ist! Ein frisch angelegter Wallos-Nutzer kann z.B. legitim (noch) keine
  // eigenen Kategorien haben. Würden wir in diesem Fall trotzdem auf die
  // lokalen Fake-Kategorien/-Währungen (negative IDs) zurückfallen, würden
  // beim Bearbeiten bereits bestehender (echter) Abos deren tatsächliche
  // Kategorie/Währung nicht mehr gefunden und stillschweigend durch die
  // erste Fake-Kategorie ersetzt - und beim Anlegen neuer Abos würde der
  // SyncService die erfundene negative ID herausfiltern, wodurch Wallos
  // ein leeres/NULL category_id speichert (Ursache der "Undefined array
  // key"-Warnungen in stats_calculations.php).
  // "household/get_household.php" ist ein neuerer Endpunkt, den ältere
  // Wallos-Versionen evtl. noch nicht kennen (404). Ein Fehlschlag HIER darf
  // NICHT den gesamten Metadaten-Fetch (inkl. der wichtigeren Währungen/
  // Kategorien) zum Scheitern bringen - "Zahler" bleibt in dem Fall einfach
  // leer/nicht auswählbar.
  Future<List<WallosHouseholdMember>> fetchHousehold() async {
    try {
      return await fetch('household/get_household.php', 'household', (j) => WallosHouseholdMember.fromJson(j));
    } catch (e) {
      return [];
    }
  }

  try {
    final results = await Future.wait([
      fetch('categories/get_categories.php', 'categories', (j) => WallosCategory.fromJson(j)),
      fetch('currencies/get_currencies.php', 'currencies', (j) => WallosCurrency.fromJson(j)),
      fetch('payment_methods/get_payment_methods.php', 'payment_methods', (j) => WallosPaymentMethod.fromJson(j)),
      // Haushaltsmitglieder ("payer_user_id") - notwendig, da Wallos den
      // Zahler bei "add"/"edit" streng gegen die "household"-Tabelle DES
      // aktuellen Nutzers validiert. Wird kein (gültiger) Wert mitgeschickt,
      // bleibt "payer_user_id" in der DB leer/NULL, was in Wallos'
      // stats_calculations.php zu "Undefined array key"-Warnungen führt.
      fetchHousehold(),
    ]);

    return MetaData(
      categories: results[0] as List<WallosCategory>,
      currencies: results[1] as List<WallosCurrency>,
      paymentMethods: results[2] as List<WallosPaymentMethod>,
      householdMembers: results[3] as List<WallosHouseholdMember>,
    );
  } catch (e) {
    // Server tatsächlich nicht erreichbar (z.B. Gerät offline, DNS-/
    // Verbindungsfehler) - hier (und nur hier) auf die lokalen
    // Standardwerte zurückfallen, damit "Abo hinzufügen" nicht blockiert.
    return MetaData(
      categories: defaultLocalCategories,
      currencies: defaultLocalCurrencies,
      paymentMethods: [],
      householdMembers: [],
    );
  }
});
