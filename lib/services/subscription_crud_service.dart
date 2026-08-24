import '../database/app_database.dart';
import '../models/subscription.dart';

/// CRUD Service für Subscriptions mit Offline-First Ansatz
class SubscriptionCrudService {
  static final SubscriptionCrudService _instance = SubscriptionCrudService._internal();
  final _db = AppDatabase();

  factory SubscriptionCrudService() {
    return _instance;
  }

  SubscriptionCrudService._internal();

  /// Adds a new subscription locally (not synced)
  Future<int> addSubscription(Subscription subscription) async {
    print('[CRUD] Füge Abo hinzu: ${subscription.name}');
    
    return await _db.insertSubscription(
      subscription,
      synced: false, // Neue Abos sind nicht synced
    );
  }

  /// Edits an existing subscription locally (marks as not synced)
  Future<int> editSubscription(Subscription subscription) async {
    print('[CRUD] Bearbeite Abo: ${subscription.name}');
    
    // Update in DB
    await _db.updateSubscription(subscription);
    
    // Markiere als nicht synced (Änderung muss zu API)
    // Wir können das Abo updaten und synced=0 setzen
    return await _markAsNotSynced(subscription.id);
  }

  /// Deletes a subscription that was never synced to the API (hard delete,
  /// the server doesn't know about it, so there's nothing to queue).
  Future<int> deleteSubscription(int id) async {
    print('[CRUD] Lösche Abo (hart): $id');
    
    return await _db.deleteSubscription(id);
  }

  /// Marks an already-synced subscription for deletion (Offline-First):
  /// the row stays in the local DB (hidden from active/inactive queries)
  /// until the next successful sync actually deletes it on the server AND
  /// locally. This ensures deleting while offline isn't lost.
  Future<int> markForDeletion(int id) async {
    print('[CRUD] Merke Abo zur Löschung vor: $id');

    return await _db.markPendingDelete(id);
  }

  /// Löscht alle lokal zwischengespeicherten Abos (z.B. beim Wechsel der
  /// Wallos-Zugangsdaten/des Accounts, damit alte und neue Daten nicht
  /// vermischt werden).
  ///
  /// SICHERHEIT: Rein lokal - macht KEINEN API-Aufruf an Wallos. Die Daten
  /// im Wallos-Webinterface bleiben davon vollständig unberührt.
  Future<void> clearAllLocalData() async {
    print('[CRUD] Lösche alle lokalen Abos (Account-/Server-Wechsel)');
    await _db.deleteAllSubscriptions();
  }

  /// Gets all pending changes (not synced)
  Future<List<dynamic>> getPendingChanges() async {
    return await _db.getPendingChanges();
  }

  /// Gets count of pending changes
  Future<int> getPendingChangesCount() async {
    return await _db.getPendingChangesCount();
  }

  /// Marks a subscription as synced
  Future<void> markAsSynced(int id) async {
    await _db.markAsSynced(id);
  }

  /// Marks a subscription as synced and links it to the remote_id assigned
  /// by the Wallos API (needed after an "add", otherwise the subscription
  /// would be duplicated the next time it is fetched from the API).
  Future<void> markAsSyncedWithRemoteId(int id, int remoteId) async {
    await _db.markAsSyncedWithRemoteId(id, remoteId);
  }

  /// Helper: Mark subscription as not synced
  Future<int> _markAsNotSynced(int id) async {
    final db = AppDatabase();
    final sqfDb = await db.database;
    
    return await sqfDb.update(
      'subscriptions',
      {'synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
