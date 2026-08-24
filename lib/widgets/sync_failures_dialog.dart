import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/subscription_provider.dart';
import '../providers/sync_provider.dart';
import '../services/sync_service.dart';

/// Dialog, der nach einem Sync-Versuch alle Abos auflistet, die NICHT
/// synchronisiert werden konnten, und dem Nutzer pro Eintrag zwei
/// Möglichkeiten anbietet:
///
/// - "Lokal löschen": Die lokale (nicht synchronisierte) Änderung wird
///   verworfen, ohne die Wallos-API erneut zu kontaktieren.
/// - "Erneut versuchen" / "Auf Server erstellen": Der Sync-Versuch für
///   GENAU dieses Abo wird wiederholt.
class SyncFailuresDialog extends ConsumerStatefulWidget {
  final List<FailedSync> failures;

  const SyncFailuresDialog({super.key, required this.failures});

  static Future<void> show(BuildContext context, List<FailedSync> failures) {
    return showDialog(
      context: context,
      builder: (_) => SyncFailuresDialog(failures: failures),
    );
  }

  @override
  ConsumerState<SyncFailuresDialog> createState() => _SyncFailuresDialogState();
}

class _SyncFailuresDialogState extends ConsumerState<SyncFailuresDialog> {
  final _syncService = SyncService();
  late List<FailedSync> _failures;
  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _failures = List.of(widget.failures);
  }

  void _refreshAppState() {
    ref.invalidate(subscriptionProvider);
    ref.invalidate(pendingChangesCountProvider);
  }

  Future<void> _retry(FailedSync failure) async {
    setState(() => _busyIds.add(failure.localId));
    final result = await _syncService.retry(failure);
    if (!mounted) return;
    setState(() {
      _busyIds.remove(failure.localId);
      final index = _failures.indexWhere((f) => f.localId == failure.localId);
      if (index == -1) return;
      if (result == null) {
        _failures.removeAt(index);
      } else {
        _failures[index] = result;
      }
    });
    _refreshAppState();
  }

  Future<void> _discard(FailedSync failure) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wirklich verwerfen?'),
        content: Text(
          failure.isPendingDelete
              ? '"${failure.name}" bleibt dann weiterhin auf dem Wallos-Server bestehen.'
              : '"${failure.name}" wird lokal entfernt' +
                  (failure.remoteId != null
                      ? ' und beim nächsten Laden wieder mit dem (unveränderten) Server-Stand ersetzt.'
                      : ' und nicht auf dem Wallos-Server angelegt.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Verwerfen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyIds.add(failure.localId));
    await _syncService.discardLocally(failure);
    if (!mounted) return;
    setState(() {
      _busyIds.remove(failure.localId);
      _failures.removeWhere((f) => f.localId == failure.localId);
    });
    _refreshAppState();
  }

  String _describeError(FailedSync failure) {
    if (failure.isPendingDelete) {
      return 'Löschen auf dem Server fehlgeschlagen: ${failure.error}';
    }
    if (failure.remoteId == null) {
      return 'Anlegen auf dem Server fehlgeschlagen: ${failure.error}';
    }
    return 'Bearbeiten auf dem Server fehlgeschlagen: ${failure.error}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nicht synchronisierte Abos'),
      content: SizedBox(
        width: double.maxFinite,
        child: _failures.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Alle Abos sind jetzt synchronisiert! 🎉')),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: _failures.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final failure = _failures[index];
                  final busy = _busyIds.contains(failure.localId);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              failure.isPendingDelete ? Icons.delete_outline : Icons.error_outline,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                failure.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _describeError(failure),
                          style: TextStyle(color: Colors.grey[700], fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        if (busy)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        else
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              TextButton.icon(
                                onPressed: () => _discard(failure),
                                icon: const Icon(Icons.delete_forever, size: 18),
                                label: Text(failure.isPendingDelete ? 'Löschung verwerfen' : 'Lokal löschen'),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _retry(failure),
                                icon: const Icon(Icons.cloud_upload, size: 18),
                                label: Text(
                                  failure.isPendingDelete
                                      ? 'Erneut löschen'
                                      : (failure.remoteId == null ? 'Auf Server erstellen' : 'Erneut versuchen'),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}
