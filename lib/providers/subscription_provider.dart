import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription.dart';
import '../database/app_database.dart';

/// FutureProvider - Lädt Abos von API oder lokal aus der Datenbank
final subscriptionProvider = FutureProvider<List<Subscription>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  var url = (prefs.getString('wallos_api_url') ?? '').trim();
  final token = (prefs.getString('wallos_api_token') ?? '').trim();

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
  
  if (locals.isEmpty) {
    throw Exception('Keine Abos vorhanden. Bitte API-Daten eingeben oder Abos hinzufügen.');
  }
  
  // Konvertiere lokale Entities zu Subscription Models
  return _convertEntitiesToSubscriptions(locals);
});

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
        inactive: entity.inactive,
        nextPayment: entity.nextPayment,
        icon: Icons.shopping_bag,
        logoUrl: entity.logoUrl,
      );
    }
    return entity as Subscription;
  }).toList();
}