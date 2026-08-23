import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_service.dart';
import '../services/subscription_crud_service.dart';

/// Provider für Anzahl ausstehender Änderungen
final pendingChangesCountProvider = FutureProvider<int>((ref) async {
  try {
    final crudService = SubscriptionCrudService();
    return await crudService.getPendingChangesCount();
  } catch (e) {
    print('[Sync Provider] Fehler beim Zählen: $e');
    return 0; // Default: Keine ausstehenden Änderungen
  }
});

/// Provider für Sync-Operation
final syncProvider = FutureProvider<SyncResult>((ref) async {
  try {
    final syncService = SyncService();
    return await syncService.syncToAPI();
  } catch (e) {
    print('[Sync Provider] Fehler beim Synchen: $e');
    return SyncResult(
      success: false,
      message: 'Sync-Fehler: $e',
      synced: 0,
    );
  }
});


