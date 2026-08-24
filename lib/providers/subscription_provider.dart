import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription.dart';
import '../database/app_database.dart';
import '../services/wallos_settings_service.dart';

/// FutureProvider - Lädt Abos von API oder lokal aus der Datenbank
final subscriptionProvider = FutureProvider<List<Subscription>>(
  (ref) async {
    final creds = await WallosSettingsService.loadSettings();
    var url = creds.url.trim();
    final token = creds.token.trim();

    // Wenn API-Credentials vorhanden sind, versuche von API zu laden
    if (url.isNotEmpty && token.isNotEmpty) {
      try {
        final apiSubs = await _fetchFromAPI(url, token);
        print('[Provider] ${apiSubs.length} Abos von API geladen und lokal gespeichert');

        // WICHTIG: Lade jetzt ALLES aus der lokalen Datenbank
        // Dadurch erhalten wir die korrekten lokalen IDs für das Löschen/Bearbeiten
        final db = AppDatabase();
        final locals = await db.getAllActiveSubscriptions();
        final allMapped = _convertEntitiesToSubscriptions(locals);

        print('[Provider] ${allMapped.length} Abos aus DB nach API-Sync geladen');
        return allMapped;
      } catch (e) {
        print('API-Fehler: $e - Nutze lokale Datenbank als Fallback');
      }
    }

    // Fallback: Lade von lokaler Datenbank
    print('Lade Abos aus lokaler Datenbank...');
    final db = AppDatabase();
    final locals = await db.getAllActiveSubscriptions();

    // WICHTIG: Weder Wallos-Zugangsdaten NOCH lokal zwischengespeicherte Abos
    // vorhanden ist der normale Zustand direkt nach der Erstinstallation -
    // die App funktioniert bewusst auch komplett OHNE Wallos-Verbindung.
    // Es wird daher KEIN Fehler geworfen, sondern einfach eine leere Liste
    // zurückgegeben - Dashboard und Abo-Liste zeigen dadurch ganz normal
    // ihren "leer"-Zustand (0 CHF, keine anstehenden Zahlungen, ...) statt
    // eines blockierenden Hinweisbildschirms.

    // Konvertiere lokale Entities zu Subscription Models
    return _convertEntitiesToSubscriptions(locals);
  },
  // WICHTIG: Riverpod versucht standardmäßig, einen fehlgeschlagenen Provider
  // automatisch mit exponentiellem Backoff bis zu 8x erneut auszuführen
  // (200ms, 400ms, 800ms, ... bis ~6-7s gedeckelt). Das ist bei ECHTEN
  // transienten Fehlern (z.B. kurzer Netzwerkaussetzer) sinnvoll - genau
  // dieser Fall wird hier oben aber bereits selbst per try/catch abgefangen
  // und fällt auf die lokale DB zurück, OHNE eine Exception zu werfen. Da
  // dieser Provider inzwischen nie mehr wirft, greift dieser Opt-out aktuell
  // nur zur Sicherheit für zukünftige Änderungen.
  retry: (retryCount, error) => null,
);

/// Hilfsfunktion: Fetch von API
Future<List<Subscription>> _fetchFromAPI(String url, String token) async {
  if (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }

  // WICHTIG: Erzwungene HTTPS-Umstellung für DuckDNS
  if (url.contains('duckdns.org') && url.startsWith('http://')) {
    url = url.replaceFirst('http://', 'https://');
  } else if (!url.startsWith('http')) {
    url = url.contains('duckdns.org') ? 'https://$url' : 'http://$url';
  }

  final apiUrl = '$url/api/subscriptions/get_subscriptions.php?api_key=$token';

  final response = await http.get(
    Uri.parse(apiUrl),
    headers: {
      'Accept': 'application/json',
      'User-Agent': 'WallosMobileApp/1.0',
    },
  ).timeout(const Duration(seconds: 10));

  if (response.statusCode == 200) {
    final Map<String, dynamic> data = json.decode(response.body);

    if (data['success'] != true) {
      throw Exception('Wallos-Fehler: ${data['title'] ?? 'Unbekannter Fehler'}');
    }

    final List<dynamic> subscriptions = data['subscriptions'] ?? [];
    final result = subscriptions
        .map((json) => Subscription.fromJson(json, baseUrl: url))
        .toList();

    // Speichere in lokaler Datenbank als Backup
    _saveToLocalDatabase(result);

    return result;
  } else {
    throw Exception('Fehler ${response.statusCode}: ${response.body}');
  }
}

/// Speichert Abos in lokale Datenbank
Future<void> _saveToLocalDatabase(List<Subscription> subscriptions) async {
  try {
    final db = AppDatabase();
    // insertSubscriptions handles ConflictAlgorithm.replace with unique remote_id
    await db.insertSubscriptions(subscriptions);
    print('✓ ${subscriptions.length} Abos von API lokal aktualisiert/gemerged');
  } catch (e) {
    print('⚠ Fehler beim Speichern lokal: $e');
  }
}

/// Konvertiert Entities zu Subscription Models
List<Subscription> _convertEntitiesToSubscriptions(List<dynamic> entities) {
  return entities.map((entity) {
    if (entity is SubscriptionEntity) {
      return Subscription(
        id: entity.id,
        remoteId: entity.remoteId,
        name: entity.name,
        price: entity.price,
        cycle: entity.cycle,
        frequency: entity.frequency,
        currencyId: entity.currencyId,
        categoryId: entity.categoryId,
        paymentMethodId: entity.paymentMethodId,
        payerUserId: entity.payerUserId,
        inactive: entity.inactive,
        nextPayment: entity.nextPayment,
        icon: Icons.shopping_bag,
        logoUrl: entity.logoUrl,
        logoHex: entity.logoHex,
      );
    }
    return entity as Subscription;
  }).toList();
}
