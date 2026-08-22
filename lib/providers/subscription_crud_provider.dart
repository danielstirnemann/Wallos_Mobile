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
    String? categoryId,
    String? paymentMethodId,
  }) async {
    if (baseUrl.isEmpty || apiKey.isEmpty) {
      return {'success': false, 'message': 'API-URL oder Token fehlt'};
    }
    
    // URL säubern
    var cleanUrl = baseUrl.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'http://$cleanUrl';
    }
    
    final url = '$cleanUrl/api/subscriptions/set_subscriptions.php';

    final body = {
      'api_key': apiKey,
      'action': 'add',
      'name': name,
      'price': price.toString(),
      'currency_id': currencyId.toString(),
      'cycle_id': cycleId.toString(),
      'frequency': frequency.toString(),
      'cycle': cycle.toString(),
      'next_payment': nextPayment,
      ...?categoryId != null ? {'category_id': categoryId} : null,
      ...?paymentMethodId != null ? {'payment_method_id': paymentMethodId} : null,
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );

    if (response.statusCode == 200) {
      return {'success': true, 'message': 'Abonnement erfolgreich hinzugefügt'};
    } else {
      return {'success': false, 'message': 'Fehler beim Hinzufügen: ${response.statusCode}'};
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
    String? categoryId,
    String? paymentMethodId,
  }) async {
    if (baseUrl.isEmpty || apiKey.isEmpty) {
      return {'success': false, 'message': 'API-URL oder Token fehlt'};
    }
    
    // URL säubern
    var cleanUrl = baseUrl.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'http://$cleanUrl';
    }
    
    final url = '$cleanUrl/api/subscriptions/set_subscriptions.php';

    final body = {
      'api_key': apiKey,
      'action': 'edit',
      'id': id.toString(),
      'name': name,
      'price': price.toString(),
      'currency_id': currencyId.toString(),
      'cycle': cycle.toString(),
      'frequency': frequency.toString(),
      'next_payment': nextPayment,
      ...?categoryId != null ? {'category_id': categoryId} : null,
      ...?paymentMethodId != null ? {'payment_method_id': paymentMethodId} : null,
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );

    if (response.statusCode == 200) {
      return {'success': true, 'message': 'Abonnement erfolgreich aktualisiert'};
    } else {
      return {'success': false, 'message': 'Fehler beim Aktualisieren: ${response.statusCode}'};
    }
  }

  static Future<Map<String, dynamic>> deleteSubscription({
    required String baseUrl,
    required String apiKey,
    required int id,
  }) async {
    if (baseUrl.isEmpty || apiKey.isEmpty) {
      return {'success': false, 'message': 'API-URL oder Token fehlt'};
    }
    
    // URL säubern
    var cleanUrl = baseUrl.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'http://$cleanUrl';
    }
    
    final url = '$cleanUrl/api/subscriptions/set_subscriptions.php';

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
      return {'success': true, 'message': 'Abonnement erfolgreich gelöscht'};
    } else {
      return {'success': false, 'message': 'Fehler beim Löschen: ${response.statusCode}'};
    }
  }
}
