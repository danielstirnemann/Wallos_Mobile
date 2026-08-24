import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sync_provider.dart';
import '../services/sync_service.dart';
import 'sync_failures_dialog.dart';

/// Sync-Badge mit Sync-Button für AppBar
class SyncBadge extends ConsumerWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount = ref.watch(pendingChangesCountProvider);

    return pendingCount.when(
      data: (count) {
        if (count == 0) {
          // Kein Sync nötig
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Tooltip(
              message: 'Alles ist synchronisiert',
              child: Icon(
                Icons.cloud_done,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          );
        }

        // Zeige Sync-Button mit Anzahl
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: SyncButton(count: count),
        );
      },
      loading: () {
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(
                Colors.white.withOpacity(0.7),
              ),
            ),
          ),
        );
      },
      error: (err, stack) {
        print('[SyncBadge] Fehler beim Laden: $err');
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Tooltip(
            message: 'Kann Sync-Status nicht laden',
            child: Icon(
              Icons.cloud_off,
              color: Colors.amber[600],
            ),
          ),
        );
      },
    );
  }
}

/// Sync-Button mit Lade-Zustand
class SyncButton extends ConsumerStatefulWidget {
  final int count;

  const SyncButton({super.key, required this.count});

  @override
  ConsumerState<SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends ConsumerState<SyncButton> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isSyncing ? null : _performSync,
      child: Tooltip(
        message: '${widget.count} Änderung${widget.count > 1 ? 'en' : ''} pending - Tippen zum Synchen',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSyncing)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              else
                Icon(
                  Icons.cloud_upload,
                  color: Colors.white,
                  size: 16,
                ),
              const SizedBox(width: 4),
              Text(
                '${widget.count}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _performSync() async {
    setState(() => _isSyncing = true);

    try {
      final syncService = SyncService();
      final result = await syncService.syncToAPI();

      if (mounted) {
        // Refresh pending count
        ref.invalidate(pendingChangesCountProvider);

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );

        // Falls einzelne Abos nicht synchronisiert werden konnten, zeige
        // einen Dialog, in dem der Nutzer pro Abo entscheiden kann, ob die
        // Änderung lokal verworfen oder der Sync erneut versucht werden soll.
        if (result.failures.isNotEmpty) {
          await SyncFailuresDialog.show(context, result.failures);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync-Fehler: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }
}
