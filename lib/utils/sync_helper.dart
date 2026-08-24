import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/subscription_provider.dart';
import '../providers/sync_provider.dart';

/// Gemeinsames Offline-First-Muster für alle Abo-Mutationen (Hinzufügen,
/// Bearbeiten, Aktivieren/Deaktivieren, Löschen):
///
/// 1. Die Änderung wurde bereits LOKAL gespeichert (synced = 0).
/// 2. Die UI wird sofort aus der lokalen DB aktualisiert (optimistisch).
/// 3. Im Hintergrund wird versucht, mit der Wallos-API zu synchronisieren.
///    Schlägt das fehl (z.B. offline), bleibt die Änderung einfach als
///    "ausstehend" markiert und wird beim nächsten Sync erneut versucht.
class SyncHelper {
  /// Aktualisiert die UI-Provider aus der lokalen DB und stößt danach einen
  /// Sync-Versuch zur Wallos-API an.
  ///
  /// HINWEIS: Das Ergebnis dieses automatischen Hintergrund-Syncs wird
  /// bewusst NICHT als SnackBar angezeigt (das wäre nach JEDEM
  /// Hinzufügen/Bearbeiten/Löschen störend). Fehlgeschlagene Abos landen
  /// stattdessen ganz normal in der "ausstehend"-Zählung (Sync-Badge oben
  /// rechts) - von dort aus löst der manuelle Sync-Button weiterhin eine
  /// eigene Meldung inkl. Fehler-Dialog aus.
  static Future<void> refreshAndSync(BuildContext context, WidgetRef ref) async {
    // Sofortiges UI-Feedback aus der lokalen DB (Offline-First).
    //
    // HINWEIS: "subscriptionProvider" versucht (falls Zugangsdaten vorhanden)
    // zuerst, frisch von der API zu laden, bevor es aus der lokalen DB liest.
    // Damit ein solcher (evtl. noch veralteter) API-Fetch NIE die gerade
    // eben lokal gespeicherte Änderung wieder rückgängig macht, bevor sie
    // hochgeladen werden konnte, überschreibt "AppDatabase.insertSubscriptions"
    // beim Zusammenführen bewusst KEINE lokal noch nicht synchronisierten
    // (synced = 0) oder zur Löschung vorgemerkten Zeilen - siehe dort.
    ref.invalidate(subscriptionProvider);
    ref.invalidate(pendingChangesCountProvider);

    try {
      await ref.refresh(syncProvider.future);

      // Nach dem Sync-Versuch erneut aktualisieren (z.B. neue remote_id).
      ref.invalidate(subscriptionProvider);
      ref.invalidate(pendingChangesCountProvider);
    } catch (e) {
      // ignore: avoid_print
      print('[SyncHelper] Fehler beim automatischen Sync: $e');
    }
  }
}
