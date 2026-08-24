import 'dart:convert';
import 'package:http/http.dart' as http;
import 'logo_upload_helper.dart';
import 'subscription_crud_service.dart';
import 'wallos_multipart_client.dart';
import 'wallos_settings_service.dart';

/// Sync Service - Hochladen von lokalen Änderungen zur API
class SyncService {
  static final SyncService _instance = SyncService._internal();
  final _crudService = SubscriptionCrudService();

  factory SyncService() {
    return _instance;
  }

  SyncService._internal();

  /// Lädt die aktuell gespeicherten API-Zugangsdaten (URL bereits bereinigt).
  /// Gibt `null` zurück, falls diese nicht (vollständig) hinterlegt sind.
  Future<({String url, String token})?> _loadCredentials() async {
    final creds = await WallosSettingsService.loadSettings();
    var url = creds.url.trim();
    final token = creds.token.trim();

    if (url.isEmpty || token.isEmpty) {
      return null;
    }

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

    return (url: url, token: token);
  }

  /// Synchronisiert ausstehende Änderungen zur API
  Future<SyncResult> syncToAPI() async {
    print('[SYNC] Starte Synchronisierung...');

    try {
      final creds = await _loadCredentials();
      if (creds == null) {
        return SyncResult(
          success: false,
          message: 'API-Credentials nicht gespeichert',
          synced: 0,
          failures: [],
        );
      }

      // Hole ausstehende Änderungen
      final pending = await _crudService.getPendingChanges();
      print('[SYNC] ${pending.length} ausstehende Änderungen gefunden');

      if (pending.isEmpty) {
        return SyncResult(
          success: true,
          message: 'Keine ausstehenden Änderungen',
          synced: 0,
          failures: [],
        );
      }

      int successCount = 0;
      final failures = <FailedSync>[];

      for (var sub in pending) {
        final error = await _syncOne(sub, creds.url, creds.token);
        if (error == null) {
          successCount++;
        } else {
          failures.add(FailedSync(
            localId: sub.id,
            remoteId: sub.remoteId,
            name: sub.name,
            isPendingDelete: sub.pendingDelete == 1,
            error: error,
          ));
        }
      }

      return SyncResult(
        success: failures.isEmpty,
        message: failures.isEmpty
            ? '$successCount Abos synchronisiert'
            : '${failures.length} fehlgeschlagen. Letzter Fehler: ${failures.last.error}',
        synced: successCount,
        failures: failures,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Sync abgebrochen: $e',
        synced: 0,
        failures: [],
      );
    }
  }

  /// Versucht, EINEN zuvor fehlgeschlagenen Eintrag erneut zu synchronisieren
  /// (z.B. aus dem "Nicht synchronisiert"-Dialog heraus). Gibt `null` zurück
  /// bei Erfolg, sonst eine aktualisierte [FailedSync] mit der neuen
  /// Fehlermeldung.
  Future<FailedSync?> retry(FailedSync failure) async {
    final creds = await _loadCredentials();
    if (creds == null) {
      return FailedSync(
        localId: failure.localId,
        remoteId: failure.remoteId,
        name: failure.name,
        isPendingDelete: failure.isPendingDelete,
        error: 'API-Credentials nicht gespeichert',
      );
    }

    // Frischen Stand aus der lokalen DB holen (könnte sich zwischenzeitlich
    // geändert haben) - falls nicht mehr vorhanden, ist nichts mehr zu tun.
    final pending = await _crudService.getPendingChanges();
    dynamic sub;
    for (final p in pending) {
      if (p.id == failure.localId) {
        sub = p;
        break;
      }
    }
    if (sub == null) {
      return null; // Bereits erledigt (z.B. durch einen anderen Sync-Lauf)
    }

    final error = await _syncOne(sub, creds.url, creds.token);
    if (error == null) {
      return null;
    }
    return FailedSync(
      localId: sub.id,
      remoteId: sub.remoteId,
      name: sub.name,
      isPendingDelete: sub.pendingDelete == 1,
      error: error,
    );
  }

  /// Entfernt einen fehlgeschlagenen Eintrag NUR lokal (harte Löschung),
  /// ohne einen weiteren API-Aufruf zu tätigen:
  ///
  /// - War es ein neues, nie synchronisiertes Abo ("add" fehlgeschlagen),
  ///   wird der Entwurf komplett verworfen.
  /// - War es eine Änderung an einem bereits synchronisierten Abo ("edit"
  ///   fehlgeschlagen), wird die lokale Änderung verworfen - beim nächsten
  ///   Laden wird der (unveränderte) Server-Stand erneut importiert.
  /// - War es eine vorgemerkte Löschung ("delete" fehlgeschlagen), wird die
  ///   Löschung verworfen - das Abo bleibt auf dem Server bestehen und wird
  ///   beim nächsten Laden wieder normal importiert.
  Future<void> discardLocally(FailedSync failure) async {
    await _crudService.deleteSubscription(failure.localId);
  }

  /// Führt den eigentlichen Sync für EIN Abo durch (add/edit/delete) und
  /// aktualisiert bei Erfolg direkt die lokale DB (synced-Flag/remote_id).
  /// Gibt bei Erfolg `null` zurück, sonst eine Fehlermeldung.
  Future<String?> _syncOne(dynamic sub, String baseUrl, String apiKey) async {
    // Wallos' set_subscriptions.php antwortet mit exakt dieser Meldung
    // ("Subscription not found" / "... does not belong to you."), wenn die
    // angefragte ID nicht (mehr) existiert - z.B. weil sie bereits manuell
    // im Webinterface gelöscht wurde. Wird verwendet, um eine vorgemerkte
    // Löschung in diesem Fall als (stillen) Erfolg statt als Fehler zu
    // behandeln.
    bool isAlreadyGoneOnServer(String message) {
      final lower = message.toLowerCase();
      return lower.contains('not found') || lower.contains('does not belong');
    }

    try {
      if (sub.pendingDelete == 1) {
        if (sub.remoteId == null) {
          // Sollte nicht vorkommen (nie synced -> sofort hart gelöscht),
          // sicherheitshalber trotzdem lokal aufräumen.
          await _crudService.deleteSubscription(sub.id);
          return null;
        }

        print('[SYNC] Versuche Löschung für: ${sub.name} (Remote ID: ${sub.remoteId})');
        final response = await _deleteSubscriptionWithResponse(
          baseUrl: baseUrl,
          apiKey: apiKey,
          remoteId: sub.remoteId,
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            await _crudService.deleteSubscription(sub.id);
            print('[SYNC] ✓ ${sub.name} erfolgreich gelöscht');
            return null;
          }
          final msg = data['title'] ?? 'API Fehler';
          if (isAlreadyGoneOnServer(msg.toString())) {
            // Der Datensatz existiert auf dem Wallos-Server bereits gar
            // nicht mehr (z.B. dort manuell im Webinterface gelöscht,
            // bevor die App-seitige Löschung synchronisiert werden konnte).
            // Das eigentliche Ziel - "existiert nicht mehr auf dem Server" -
            // ist damit bereits erreicht - das ist KEIN Sync-Fehler.
            await _crudService.deleteSubscription(sub.id);
            print('[SYNC] ✓ ${sub.name} war auf dem Server bereits gelöscht - lokal entfernt.');
            return null;
          }
          print('[SYNC] ✗ Löschen von ${sub.name} fehlgeschlagen: $msg');
          return msg.toString();
        }
        final msg = 'Server Status: ${response.statusCode}';
        print('[SYNC] ✗ Löschen von ${sub.name} fehlgeschlagen: $msg');
        return msg;
      }

      print('[SYNC] Versuche Upload für: ${sub.name} (Local ID: ${sub.id}, Remote ID: ${sub.remoteId})');
      final response = await _uploadSubscriptionWithResponse(
        baseUrl: baseUrl,
        apiKey: apiKey,
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
          print('[SYNC] ✓ ${sub.name} erfolgreich synchronisiert');
          return null;
        }
        final msg = data['title'] ?? 'API Fehler';
        print('[SYNC] ✗ ${sub.name} fehlgeschlagen: $msg');
        return msg.toString();
      }
      final msg = 'Server Status: ${response.statusCode}';
      print('[SYNC] ✗ ${sub.name} fehlgeschlagen: $msg');
      return msg;
    } catch (e) {
      print('[SYNC] Fehler beim Upload von ${sub.name}: $e');
      return e.toString();
    }
  }

  /// Hilfsfunktion: Lädt ein Abo zur API hoch und gibt Response zurück
  Future<http.Response> _uploadSubscriptionWithResponse({
    required String baseUrl,
    required String apiKey,
    required dynamic subscription,
  }) async {
    final url = '$baseUrl/api/subscriptions/set_subscriptions.php';

    // Sicherstellen, dass alle Werte als Strings vorhanden sind.
    //
    // WICHTIG: "category_id", "payment_method_id" und "payer_user_id" sind
    // laut Wallos-API optionale Felder, die (falls angegeben) streng gegen
    // die Tabellen der Kategorien/Zahlungsmethoden/Haushaltsmitglieder DES
    // AKTUELLEN Nutzers geprüft werden ("WHERE id = :id AND user_id = :userId").
    // Ein erfundener Platzhalter-Wert wie "1" schlägt fehl, sobald dieser
    // Datensatz beim jeweiligen Wallos-Nutzer nicht existiert (z.B. "Invalid
    // payer ID"). Deshalb werden diese Felder nur mitgeschickt, wenn wir
    // einen tatsächlich bekannten Wert haben - beim "edit" behält Wallos den
    // bisherigen Wert bei, wenn das Feld gar nicht im Request enthalten ist.
    // WICHTIG: Währung/Kategorie können auch aus der eingebauten,
    // ausschließlich LOKALEN Standardliste stammen (siehe
    // defaultLocalCurrencies/defaultLocalCategories in default_meta_data.dart) -
    // z.B. wenn das Abo ohne Wallos-Verbindung angelegt wurde. Diese haben
    // bewusst NEGATIVE IDs, die auf KEINER echten Wallos-Instanz existieren.
    // Würden wir sie unverändert mitschicken, würde die Wallos-API mit
    // "Invalid currency/category ID" fehlschlagen. Daher werden negative IDs
    // hier herausgefiltert (Währung fällt dann auf Wallos' eigenen Standard
    // zurück, Kategorie bleibt einfach leer) - der Nutzer kann die korrekte
    // Währung/Kategorie später beim Bearbeiten aus der dann echten
    // Wallos-Liste nachtragen.
    final int? currencyId = (subscription.currencyId != null && subscription.currencyId > 0)
        ? subscription.currencyId as int
        : null;
    final int? categoryId = (subscription.categoryId != null && subscription.categoryId > 0)
        ? subscription.categoryId as int
        : null;

    final body = {
      'api_key': apiKey,
      'action': subscription.remoteId == null ? 'add' : 'edit',
      if (subscription.remoteId != null) 'id': subscription.remoteId.toString(),
      'name': subscription.name.toString(),
      'price': subscription.price.toString(),
      'currency_id': (currencyId ?? 1).toString(),
      if (categoryId != null) 'category_id': categoryId.toString(),
      if (subscription.paymentMethodId != null) 'payment_method_id': subscription.paymentMethodId.toString(),
      // WICHTIG: Ohne "payer_user_id" speichert Wallos beim Anlegen/
      // Bearbeiten NULL in der Spalte "payer_user_id". Das führt in
      // Wallos' eigener stats_calculations.php zu "Undefined array key"-
      // Warnungen (siehe $members[$payerId] / $memberCost[$payerId]).
      // Der Wert wird streng gegen die "household"-Tabelle DES aktuellen
      // Nutzers validiert, ein erfundener Platzhalter würde daher
      // fehlschlagen - deshalb nur mitschicken, wenn wir einen
      // tatsächlich bekannten (vom Nutzer gewählten) Wert haben.
      if (subscription.payerUserId != null) 'payer_user_id': subscription.payerUserId.toString(),
      'frequency': (subscription.frequency ?? 1).toString(),
      'cycle': (subscription.cycle ?? 1).toString(),
      'inactive': (subscription.inactive ?? 0).toString(),
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
    final String? logoHex = subscription.logoHex;
    final preparedLogo = await LogoUploadHelper.prepare(logoUrl, hexColor: logoHex);
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

  /// Hilfsfunktion: Löscht ein Abo auf der API (für vorgemerkte Löschungen)
  Future<http.Response> _deleteSubscriptionWithResponse({
    required String baseUrl,
    required String apiKey,
    required int remoteId,
  }) async {
    final url = '$baseUrl/api/subscriptions/set_subscriptions.php';
    final body = {
      'api_key': apiKey,
      'action': 'delete',
      'id': remoteId.toString(),
    };

    print('[SYNC] Sende Lösch-POST an $url für Remote ID $remoteId');

    return await http.post(
      Uri.parse(url),
      body: body,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    ).timeout(const Duration(seconds: 15));
  }
}

/// Ein einzelnes Abo, dessen Synchronisierung fehlgeschlagen ist.
class FailedSync {
  final int localId;
  final int? remoteId;
  final String name;
  final bool isPendingDelete;
  final String error;

  FailedSync({
    required this.localId,
    this.remoteId,
    required this.name,
    required this.isPendingDelete,
    required this.error,
  });
}

/// Result von Sync-Operation
class SyncResult {
  final bool success;
  final String message;
  final int synced;
  final List<FailedSync> failures;

  SyncResult({
    required this.success,
    required this.message,
    required this.synced,
    this.failures = const [],
  });

  @override
  String toString() => 'SyncResult(success: $success, message: $message, synced: $synced, failures: ${failures.length})';
}
