import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription.dart';
import '../services/subscription_crud_service.dart';
import '../providers/subscription_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/subscription_form_dialog.dart';

/// Hilfsklasse für alle Dialog-Operationen (Add/Edit/Delete)
class SubscriptionDialogHandler {
  static final _crudService = SubscriptionCrudService();

  /// Zeigt Add-Dialog und speichert LOKAL
  static void showAddDialog(
    BuildContext context,
    WidgetRef ref,
    String baseUrl,
    String apiKey,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => SubscriptionFormDialog(
        onSave: (data) async {
          try {
            // 1. Erstelle Abo Objekt
            final newSub = Subscription(
              id: 0, // 0 bedeutet: Neue lokale ID generieren
              name: data['name'],
              price: data['price'],
              cycle: data['cycle'],
              frequency: data['frequency'] ?? 1,
              currencyId: data['currency_id'],
              categoryId: data['category_id'],
              paymentMethodId: data['payment_method_id'],
              inactive: 0,
              nextPayment: data['next_payment'],
              logoUrl: data['logo_url'],
            );

            // 2. LOKAL speichern (Offline-First)
            await _crudService.addSubscription(newSub);
            
            print('[Offline-First] Abo lokal gespeichert: ${newSub.name}');
            
            // 3. UI Feedback
            if (context.mounted) {
              _handleLocalSuccess(
                context: context,
                dialogContext: dialogContext,
                ref: ref,
                message: 'Abo gespeichert. Synchronisiere...',
              );
            }

            // 4. Automatisch mit der Wallos-API synchronisieren
            _autoSync(context, ref);
          } catch (e) {
            print('Fehler beim lokalen Speichern: $e');
            _handleDialogError(
              context: context,
              dialogContext: dialogContext,
              error: e.toString(),
            );
          }
        },
      ),
    );
  }

  /// Verarbeitet lokalen Erfolg
  static void _handleLocalSuccess({
    required BuildContext context,
    required BuildContext dialogContext,
    required WidgetRef ref,
    required String message,
  }) {
    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    }

    // Refresh der UI aus lokaler DB
    // ignore: unused_result
    ref.refresh(subscriptionProvider);
    // Refresh der Sync-Anzeige
    // ignore: unused_result
    ref.refresh(pendingChangesCountProvider);
  }

  /// Synchronisiert automatisch mit der Wallos-API und zeigt das Ergebnis an
  static Future<void> _autoSync(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref.refresh(syncProvider.future);

      // Refresh der UI nach dem Sync
      // ignore: unused_result
      ref.refresh(subscriptionProvider);
      // ignore: unused_result
      ref.refresh(pendingChangesCountProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green.shade700 : Colors.red,
          ),
        );
      }
    } catch (e) {
      print('[AutoSync] Fehler beim automatischen Sync: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync fehlgeschlagen: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Verarbeitet Dialog-Fehler
  static void _handleDialogError({
    required BuildContext context,
    required BuildContext dialogContext,
    required String error,
  }) {
    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $error'), backgroundColor: Colors.red),
      );
    }
  }
}
