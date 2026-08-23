import 'package:http/http.dart' as http;

/// Service für Wallos-Verbindungstests
class WallosConnectionService {
  /// Testet die Verbindung zu Wallos
  /// Gibt ein Tuple mit (isSuccess, statusCode) zurück
  static Future<({bool isSuccess, int statusCode})> testConnection({
    required String url,
    required String token,
  }) async {
    if (url.isEmpty || token.isEmpty) {
      throw Exception('URL und Token erforderlich');
    }

    var finalUrl = url.trim();
    
    // URL säubern
    if (finalUrl.endsWith('/')) {
      finalUrl = finalUrl.substring(0, finalUrl.length - 1);
    }

    // Wallos-Endpunkt
    finalUrl = '$finalUrl/api/subscriptions/get_subscriptions.php?api_key=$token';

    try {
      final response = await http
          .get(
            Uri.parse(finalUrl),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'WallosMobileApp/1.0',
            },
          )
          .timeout(const Duration(seconds: 10));

      return (
        isSuccess: response.statusCode == 200,
        statusCode: response.statusCode,
      );
    } catch (e) {
      rethrow;
    }
  }
}
