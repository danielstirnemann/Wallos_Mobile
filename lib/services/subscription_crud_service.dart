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

  /// Deletes a subscription locally (marks as not synced first)
  Future<int> deleteSubscription(int id) async {
    print('[CRUD] Lösche Abo: $id');
    
    return await _db.deleteSubscription(id);
  }

  /// Gets all active subscriptions
  Future<List<dynamic>> getActiveSubscriptions() async {
    return await _db.getAllActiveSubscriptions();
  }

  /// Gets all inactive subscriptions
  Future<List<dynamic>> getInactiveSubscriptions() async {
    return await _db.getAllInactiveSubscriptions();
  }

  /// Gets all pending changes (not synced)
  Future<List<dynamic>> getPendingChanges() async {
    return await _db.getPendingChanges();
  }

  /// Gets count of pending changes
  Future<int> getPendingChangesCount() async {
    return await _db.getPendingChangesCount();
  }

  /// Marks all changes as synced
  Future<void> markAllAsSynced() async {
    await _db.markAllAsSynced();
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
