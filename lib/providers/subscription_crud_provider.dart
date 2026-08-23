import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class SubscriptionCrudProvider {
  /// POST-Request ohne automatisches Redirect-Folgen (verhindert 301-Probleme)
  static Future<http.Response> _postWithoutRedirect(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? body,
  }) async {
    // Nutze HttpClient direkt ohne auto-redirects
    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 30);
    
    try {
      final request = await httpClient.postUrl(url);
      
      // Headers
      headers?.forEach((key, value) => request.headers.set(key, value));
      
      // Body als Form-Data
      if (body != null) {
        final bodyString = body.entries
            .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
            .join('&');
        request.write(bodyString);
      }
      
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      
      return http.Response(responseBody, response.statusCode);
    } catch (e) {
      print('[ERROR] _postWithoutRedirect failed: $e');
      return http.Response('Netzwerkfehler: $e', 0);
    } finally {
      httpClient.close();
    }
  }
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
      print('[ADD] FEHLER: baseUrl leer oder apiKey leer');
      return {'success': false, 'message': 'API-URL oder Token fehlt'};
    }
    
    var cleanUrl = baseUrl.trim();
    if (cleanUrl.endsWith('/')) cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    
    // Schema hinzufügen wenn nicht vorhanden
    if (!cleanUrl.startsWith('http')) {
      // Externe URLs (mit . oder duckdns) sollten HTTPS sein
      cleanUrl = cleanUrl.contains('duckdns') ? 'https://$cleanUrl' : 'http://$cleanUrl';
    }
    
    // WICHTIG: Wenn die URL http:// hat aber es ist eine externe URL (duckdns), 
    // ändere es zu https:// da DuckDNS zu HTTPS redirected
    if (cleanUrl.startsWith('http://') && cleanUrl.contains('duckdns')) {
      cleanUrl = cleanUrl.replaceFirst('http://', 'https://');
    }
    
    final url = '$cleanUrl/api/subscriptions/set_subscriptions.php';
    print('[ADD] URL: $url');
    print('[ADD] API-Key: ${apiKey.substring(0, 10)}...');

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
      print('[ADD] Body: ${body.keys.toList()}');
      final response = await _postWithoutRedirect(
        Uri.parse(url),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );
      
      print('[ADD] Status: ${response.statusCode}');
      print('[ADD] Response: ${response.body.substring(0, 100)}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {'success': true, 'message': 'Erfolgreich hinzugefügt'};
        } else {
          return {'success': false, 'message': data['title'] ?? 'Wallos-Fehler'};
        }
      }
      print('[ADD] Server-Fehler: ${response.statusCode}');
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
    if (!cleanUrl.startsWith('http')) {
      cleanUrl = cleanUrl.contains('duckdns') ? 'https://$cleanUrl' : 'http://$cleanUrl';
    }
    if (cleanUrl.startsWith('http://') && cleanUrl.contains('duckdns')) {
      cleanUrl = cleanUrl.replaceFirst('http://', 'https://');
    }
    
    final url = '$cleanUrl/api/subscriptions/set_subscriptions.php';

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

    final response = await _postWithoutRedirect(
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

  /// Togglet den Status eines Abos (aktiv <-> inaktiv)
  static Future<Map<String, dynamic>> toggleInactiveStatus({
    required String baseUrl,
    required String apiKey,
    required int id,
    required int currentInactiveStatus,  // 0=aktiv, 1=inaktiv
  }) async {
    if (baseUrl.isEmpty || apiKey.isEmpty) {
      return {'success': false, 'message': 'API-URL oder Token fehlt'};
    }

    var cleanUrl = baseUrl.trim();
    if (cleanUrl.endsWith('/')) cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    if (!cleanUrl.startsWith('http')) {
      cleanUrl = cleanUrl.contains('duckdns') ? 'https://$cleanUrl' : 'http://$cleanUrl';
    }
    if (cleanUrl.startsWith('http://') && cleanUrl.contains('duckdns')) {
      cleanUrl = cleanUrl.replaceFirst('http://', 'https://');
    }

    final url = '$cleanUrl/api/subscriptions/set_subscriptions.php';
    final newInactiveStatus = currentInactiveStatus == 0 ? 1 : 0;  // Toggle

    final body = {
      'api_key': apiKey,
      'action': 'edit',
      'id': id.toString(),
      'inactive': newInactiveStatus.toString(),
    };

    try {
      final response = await _postWithoutRedirect(
        Uri.parse(url),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final statusText = newInactiveStatus == 0 ? 'aktiviert' : 'deaktiviert';
        return {'success': data['success'] == true, 'message': 'Abo $statusText'};
      }
      return {'success': false, 'message': 'Fehler: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Fehler: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteSubscription({
    required String baseUrl,
    required String apiKey,
    required int id,
  }) async {
    var cleanUrl = baseUrl.trim();
    if (cleanUrl.endsWith('/')) cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    if (!cleanUrl.startsWith('http')) {
      cleanUrl = cleanUrl.contains('duckdns') ? 'https://$cleanUrl' : 'http://$cleanUrl';
    }
    if (cleanUrl.startsWith('http://') && cleanUrl.contains('duckdns')) {
      cleanUrl = cleanUrl.replaceFirst('http://', 'https://');
    }
    
    final url = '$cleanUrl/api/subscriptions/set_subscriptions.php';

    final body = {
      'api_key': apiKey,
      'action': 'delete',
      'id': id.toString(),
    };

    final response = await _postWithoutRedirect(
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
