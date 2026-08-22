import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription.dart';

final subscriptionProvider = FutureProvider<List<Subscription>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  var url = (prefs.getString('wallos_api_url') ?? '').trim();
  final token = (prefs.getString('wallos_api_token') ?? '').trim();

  if (url.isEmpty || token.isEmpty) {
    throw Exception('Bitte API-URL und Token in den Einstellungen hinterlegen.');
  }

  // URL säubern (kein / am Ende der Basis-URL)
  if (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }

  final apiUrl = '$url/api/subscriptions/get_subscriptions.php?api_key=$token';

  try {
    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'WallosMobileApp/1.0',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);

      if (data['success'] != true) {
        throw Exception('Wallos-Fehler: ${data['title'] ?? 'Unbekannter Fehler'}');
      }

      final List<dynamic> subscriptions = data['subscriptions'] ?? [];
      return subscriptions
          .map((json) => Subscription.fromJson(json, baseUrl: url))
          .toList();
    } else {
      throw Exception('Fehler ${response.statusCode}: ${response.body}');
    }
  } catch (e) {
    throw Exception('Verbindung fehlgeschlagen: $e');
  }
});