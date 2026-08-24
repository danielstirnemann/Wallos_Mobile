import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription.dart';
import '../services/subscription_crud_service.dart';
import 'sync_helper.dart';
import '../widgets/subscription_form_dialog.dart';

/// Hilfsklasse für alle Dialog-Operationen (Add/Edit/Delete)
class SubscriptionDialogHandler {
  static final _crudService = SubscriptionCrudService();

  /// Zeigt Add-Dialog und speichert LOKAL
  static void showAddDialog(
    BuildContext context,
    WidgetRef ref,
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
              payerUserId: data['payer_user_id'],
              inactive: 0,
              nextPayment: data['next_payment'],
              logoUrl: data['logo_url'],
              logoHex: data['logo_hex'],
            );

            // 2. LOKAL speichern (Offline-First)
            await _crudService.addSubscription(newSub);
            
            print('[Offline-First] Abo lokal gespeichert: ${newSub.name}');
            
            // 3. UI Feedback
            if (context.mounted) {
              _handleLocalSuccess(
                context: context,
                dialogContext: dialogContext,
                message: 'Abo gespeichert. Synchronisiere...',
              );
            }

            // 4. Automatisch mit der Wallos-API synchronisieren
            SyncHelper.refreshAndSync(context, ref);
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
