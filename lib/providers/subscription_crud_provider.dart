import 'dart:convert';
import 'package:http/http.dart' as http;

class SubscriptionCrudProvider {
  static Future<Map<String, dynamic>> addSubscription({
    required String baseUrl,
    required String apiKey,
    required String name,
    required double price,
    required int currencyId,
    required int cycleId,
    required int frequency,
    required int cycle,
    required String nextPayment,
    int? categoryId,
    int? paymentMethodId,
  }) async {
    if (baseUrl.isEmpty || apiKey.isEmpty) {
      return {'success': false, 'message': 'API-URL oder Token fehlt'};
    }
    
    var cleanUrl = baseUrl.trim();
    if (cleanUrl.endsWith('/')) cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    if (!cleanUrl.startsWith('http')) cleanUrl = 'http://$cleanUrl';
    
    final url = '$cleanUrl/api/subscriptions/set_subscriptions.php?api_key=$apiKey';

    // Sende nur die Felder, die Wallos erwartet (wie das Webinterface)
    final Map<String, String> body = {
      'api_key': apiKey,
      'action': 'add',
      'name': name,
      'price': price.toString(),
      'currency_id': currencyId.toString(),
      'category_id': (categoryId ?? 1).toString(),
      'frequency': frequency.toString(),
      'cycle': cycle.toString(),
      'payment_method_id': (paymentMethodId ?? 1).toString(),
      'payer_user_id': '1',
      'next_payment': nextPayment,
      'auto_renew': 'on',
      'start_date': DateTime.now().toString().split(' ')[0],
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {'success': true, 'message': 'Erfolgreich hinzugefügt'};
        } else {
          return {'success': false, 'message': data['title'] ?? 'Wallos-Fehler'};
        }
      }
      return {'success': false, 'message': 'Server-Fehler: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Verbindungsproblem: $e'};
    }
  }

  static Future<Map<String, dynamic>> editSubscription({
    required String baseUrl,
    required String apiKey,
    required int id,
    required String name,
    required double price,
    required int currencyId,
    required int cycle,
    required int frequency,
    required String nextPayment,
    int? categoryId,
    int? paymentMethodId,
  }) async {
    var cleanUrl = baseUrl.trim();
    if (cleanUrl.endsWith('/')) cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    final url = '$cleanUrl/api/subscriptions/set_subscriptions.php?api_key=$apiKey';

    final body = {
      'api_key': apiKey,
      'action': 'edit',
      'id': id.toString(),
      'name': name,
      'price': price.toString(),
      'currency_id': currencyId.toString(),
      'category_id': (categoryId ?? 1).toString(),
      'frequency': frequency.toString(),
      'cycle': cycle.toString(),
      'payment_method_id': (paymentMethodId ?? 1).toString(),
      'next_payment': nextPayment,
      'auto_renew': 'on',
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'message': data['title'] ?? 'Update'};
    }
    return {'success': false, 'message': 'Fehler: ${response.statusCode}'};
  }

  static Future<Map<String, dynamic>> deleteSubscription({
    required String baseUrl,
    required String apiKey,
    required int id,
  }) async {
    var cleanUrl = baseUrl.trim();
    if (cleanUrl.endsWith('/')) cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    final url = '$cleanUrl/api/subscriptions/set_subscriptions.php?api_key=$apiKey';

    final body = {
      'api_key': apiKey,
      'action': 'delete',
      'id': id.toString(),
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'message': data['title'] ?? 'Löschen'};
    }
    return {'success': false, 'message': 'Fehler: ${response.statusCode}'};
  }
}
