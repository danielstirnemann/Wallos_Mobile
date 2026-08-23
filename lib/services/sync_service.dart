import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'logo_upload_helper.dart';
import 'subscription_crud_service.dart';
import 'wallos_multipart_client.dart';

/// Sync Service - Hochladen von lokalen Änderungen zur API
class SyncService {
  static final SyncService _instance = SyncService._internal();
  final _crudService = SubscriptionCrudService();

  factory SyncService() {
    return _instance;
  }

  SyncService._internal();

  /// Synchronisiert ausstehende Änderungen zur API
  Future<SyncResult> syncToAPI() async {
    print('[SYNC] Starte Synchronisierung...');

    try {
      // 1. Hole API-Credentials
      final prefs = await SharedPreferences.getInstance();
      var url = (prefs.getString('wallos_api_url') ?? '').trim();
      final token = (prefs.getString('wallos_api_token') ?? '').trim();

      if (url.isEmpty || token.isEmpty) {
        return SyncResult(
          success: false,
          message: 'API-Credentials nicht gespeichert',
          synced: 0,
        );
      }

      // 2. Hole ausstehende Änderungen
      final pending = await _crudService.getPendingChanges();
      print('[SYNC] ${pending.length} ausstehende Änderungen gefunden');

      if (pending.isEmpty) {
        return SyncResult(
          success: true,
          message: 'Keine ausstehenden Änderungen',
          synced: 0,
        );
      }

      // 3. URL säubern
      if (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }

      // WICHTIG: Erzwungene HTTPS-Umstellung für DuckDNS (verhindert 301 Fehler)
      if (url.contains('duckdns.org') && url.startsWith('http://')) {
        print('[SYNC] Korrigiere URL von http auf https für DuckDNS...');
        url = url.replaceFirst('http://', 'https://');
      } else if (!url.startsWith('http')) {
        url = url.contains('duckdns.org') ? 'https://$url' : 'http://$url';
      }

      // 4. Hochladen jedes Abos
      int successCount = 0;
      int failCount = 0;
      String lastErrorMessage = '';

      for (var sub in pending) {
        try {
          print('[SYNC] Versuche Upload für: ${sub.name} (Local ID: ${sub.id}, Remote ID: ${sub.remoteId})');
          final response = await _uploadSubscriptionWithResponse(
            baseUrl: url,
            apiKey: token,
            subscription: sub,
          );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['success'] == true) {
              // Bei "add" liefert die API die neu vergebene subscriptionId -
              // diese MUSS lokal als remote_id gespeichert werden, sonst wird
              // das Abo beim nächsten Laden von der API als Duplikat angelegt.
              final newRemoteId = sub.remoteId == null
                  ? int.tryParse(data['subscriptionId']?.toString() ?? '')
                  : null;
              if (newRemoteId != null) {
                await _crudService.markAsSyncedWithRemoteId(sub.id, newRemoteId);
              } else {
                await _crudService.markAsSynced(sub.id);
              }
              successCount++;
              print('[SYNC] ✓ ${sub.name} erfolgreich synchronisiert');
            } else {
              failCount++;
              lastErrorMessage = data['title'] ?? 'API Fehler';
              print('[SYNC] ✗ ${sub.name} fehlgeschlagen: $lastErrorMessage');
            }
          } else {
            failCount++;
            lastErrorMessage = 'Server Status: ${response.statusCode}';
            print('[SYNC] ✗ ${sub.name} fehlgeschlagen: $lastErrorMessage');
          }
        } catch (e) {
          print('[SYNC] Fehler beim Upload von ${sub.name}: $e');
          failCount++;
          lastErrorMessage = e.toString();
        }
      }

      return SyncResult(
        success: failCount == 0,
        message: failCount == 0 
            ? '$successCount Abos synchronisiert' 
            : '$failCount fehlgeschlagen. Letzter Fehler: $lastErrorMessage',
        synced: successCount,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Sync abgebrochen: $e',
        synced: 0,
      );
    }
  }

  /// Hilfsfunktion: Lädt ein Abo zur API hoch und gibt Response zurück
  Future<http.Response> _uploadSubscriptionWithResponse({
    required String baseUrl,
    required String apiKey,
    required dynamic subscription,
  }) async {
    final url = '$baseUrl/api/subscriptions/set_subscriptions.php';

    // Sicherstellen, dass alle Werte als Strings vorhanden sind
    final body = {
      'api_key': apiKey,
      'action': subscription.remoteId == null ? 'add' : 'edit',
      if (subscription.remoteId != null) 'id': subscription.remoteId.toString(),
      'name': subscription.name.toString(),
      'price': subscription.price.toString(),
      'currency_id': (subscription.currencyId ?? 1).toString(),
      'category_id': (subscription.categoryId ?? 1).toString(),
      'payment_method_id': (subscription.paymentMethodId ?? 1).toString(),
      'frequency': (subscription.frequency ?? 1).toString(),
      'cycle': (subscription.cycle ?? 1).toString(),
      'inactive': (subscription.inactive ?? 0).toString(),
      'payer_user_id': '1',
      'auto_renew': 'on',
      'start_date': DateTime.now().toString().split(' ')[0],
      if (subscription.nextPayment != null && subscription.nextPayment.isNotEmpty) 
        'next_payment': subscription.nextPayment.toString(),
    };

    print('[SYNC] Sende POST an $url mit Body: $body');

    // Logo als Datei mitschicken (Wallos erwartet dafür "logo_url" zum
    // serverseitigen Download oder "$_FILES['logo']" - das per-"logo"-Feld
    // gesendete Text wurde bisher schlicht ignoriert). Die SVG-Icons werden
    // hier lokal zu PNG rasterisiert, da PHP/GD kein SVG dekodieren kann.
    final String? logoUrl = subscription.logoUrl;
    final preparedLogo = await LogoUploadHelper.prepare(logoUrl);
    if (preparedLogo != null) {
      return await WallosMultipartClient.postWithoutRedirect(
        Uri.parse(url),
        fields: body,
        fileFieldName: 'logo',
        fileBytes: preparedLogo.bytes,
        fileName: preparedLogo.filename,
      );
    }

    return await http.post(
      Uri.parse(url),
      body: body,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    ).timeout(const Duration(seconds: 15));
  }
}

/// Result von Sync-Operation
class SyncResult {
  final bool success;
  final String message;
  final int synced;

  SyncResult({
    required this.success,
    required this.message,
    required this.synced,
  });

  @override
  String toString() => 'SyncResult(success: $success, message: $message, synced: $synced)';
}
