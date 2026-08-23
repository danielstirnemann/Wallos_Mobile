import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/subscription_crud_provider.dart';
import '../providers/subscription_provider.dart';
import '../widgets/subscription_form_dialog.dart';

/// Hilfsklasse für alle Dialog-Operationen (Add/Edit/Delete)
class SubscriptionDialogHandler {
  /// Zeigt Add-Dialog und führt Abo hinzu
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
            final result = await SubscriptionCrudProvider.addSubscription(
              baseUrl: baseUrl,
              apiKey: apiKey,
              name: data['name'],
              price: data['price'],
              currencyId: data['currency_id'],
              cycleId: data['cycle'],
              cycle: data['cycle'],
              frequency: data['frequency'],
              nextPayment: data['next_payment'],
              categoryId: data['category_id'],
              paymentMethodId: data['payment_method_id'],
            );
            print('API-Antwort: ${result['success']} - ${result['message']}');
            
            _handleDialogResult(
              context: context,
              dialogContext: dialogContext,
              ref: ref,
              result: result,
            );
          } catch (e) {
            print('Fehler beim Hinzufügen: $e');
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

  /// Verarbeitet erfolgreiche Dialog-Operationen
  static void _handleDialogResult({
    required BuildContext context,
    required BuildContext dialogContext,
    required WidgetRef ref,
    required Map<String, dynamic> result,
  }) {
    // Dialog schließen
    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }

    // SnackBar zeigen
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'])),
      );
    }

    // Refresh, wenn erfolgreich
    if (result['success'] == true) {
      print('Operation erfolgreich - starte Refresh...');
      // ignore: unused_result
      ref.refresh(subscriptionProvider);
    }
  }

  /// Verarbeitet Dialog-Fehler
  static void _handleDialogError({
    required BuildContext context,
    required BuildContext dialogContext,
    required String error,
  }) {
    // Dialog schließen
    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }

    // Fehler anzeigen
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $error')),
      );
    }
  }
}
