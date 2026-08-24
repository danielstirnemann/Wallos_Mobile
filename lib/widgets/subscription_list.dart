import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription.dart';
import '../services/subscription_crud_service.dart';
import '../utils/hex_color.dart';
import '../utils/sync_helper.dart';
import 'safe_svg_logo.dart';
import 'subscription_form_dialog.dart';

class SubscriptionList extends ConsumerWidget {
  final List<Subscription> subscriptions;

  const SubscriptionList({
    super.key,
    required this.subscriptions,
  });

  /// Erstellt eine Kopie von [subscription] mit angepassten Feldern.
  /// Wird für Toggle/Edit benötigt, da [Subscription] unveränderlich ist.
  Subscription _copyWith(
    Subscription subscription, {
    String? name,
    double? price,
    int? cycle,
    int? frequency,
    int? currencyId,
    int? categoryId,
    int? paymentMethodId,
    int? payerUserId,
    int? inactive,
    String? nextPayment,
    String? logoUrl,
    String? logoHex,
  }) {
    return Subscription(
      id: subscription.id,
      remoteId: subscription.remoteId,
      name: name ?? subscription.name,
      price: price ?? subscription.price,
      cycle: cycle ?? subscription.cycle,
      frequency: frequency ?? subscription.frequency,
      currencyId: currencyId ?? subscription.currencyId,
      categoryId: categoryId ?? subscription.categoryId,
      paymentMethodId: paymentMethodId ?? subscription.paymentMethodId,
      payerUserId: payerUserId ?? subscription.payerUserId,
      inactive: inactive ?? subscription.inactive,
      nextPayment: nextPayment ?? subscription.nextPayment,
      icon: subscription.icon,
      logoUrl: logoUrl ?? subscription.logoUrl,
      logoHex: logoHex ?? subscription.logoHex,
    );
  }

  /// Aktiviert/Deaktiviert ein Abo. Offline-First: die Änderung wird zuerst
  /// LOKAL gespeichert (synced=0), danach wird im Hintergrund synchronisiert.
  void _toggleStatus(BuildContext context, WidgetRef ref, Subscription subscription) async {
    try {
      final updated = _copyWith(
        subscription,
        inactive: subscription.inactive == 0 ? 1 : 0,
      );

      await SubscriptionCrudService().editSubscription(updated);

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updated.inactive == 0 ? 'Abo aktiviert' : 'Abo deaktiviert'),
            backgroundColor: Colors.orange.shade700,
          ),
        );
        await SyncHelper.refreshAndSync(context, ref);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Subscription subscription) {
    showDialog(
      context: context,
      builder: (dialogContext) => SubscriptionFormDialog(
        subscription: subscription,
        onSave: (data) async {
          try {
            // Offline-First: Änderung zuerst LOKAL speichern (synced=0),
            // danach im Hintergrund mit der Wallos-API synchronisieren.
            final updated = _copyWith(
              subscription,
              name: data['name'],
              price: data['price'],
              cycle: data['cycle'],
              frequency: data['frequency'] ?? 1,
              currencyId: data['currency_id'],
              categoryId: data['category_id'] as int?,
              paymentMethodId: data['payment_method_id'] as int?,
              payerUserId: data['payer_user_id'] as int?,
              nextPayment: data['next_payment'],
              logoUrl: data['logo_url'],
              logoHex: data['logo_hex'],
            );

            await SubscriptionCrudService().editSubscription(updated);

            // Dialog schließen ZUERST
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }

            // Dann SnackBar + Sync im Hintergrund anstoßen
            if (context.mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Abo aktualisiert. Synchronisiere...'),
                  backgroundColor: Colors.orange,
                ),
              );
              await SyncHelper.refreshAndSync(context, ref);
            }
          } catch (e) {
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Fehler: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Subscription subscription) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bestätigung'),
        content: Text('Möchtest du "${subscription.name}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final crud = SubscriptionCrudService();

                if (subscription.remoteId != null) {
                  // Bereits synchronisiert: Offline-First -> nur zur
                  // Löschung vormerken. Die eigentliche Löschung auf dem
                  // Server erfolgt beim nächsten (Auto-)Sync, damit das
                  // Löschen auch ohne Internetverbindung funktioniert.
                  await crud.markForDeletion(subscription.id);
                } else {
                  // Noch nie synchronisiert -> der Server weiß nichts davon,
                  // daher kann sofort hart gelöscht werden.
                  await crud.deleteSubscription(subscription.id);
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Abo gelöscht. Synchronisiere...'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  await SyncHelper.refreshAndSync(context, ref);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Fehler: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: subscriptions.length,
      itemBuilder: (context, index) {
        final item = subscriptions[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 48,
              height: 48,
              color: Colors.grey.withOpacity(0.1),
              padding: const EdgeInsets.all(8),
              child: item.logoUrl != null
                  ? (item.logoUrl!.endsWith('.svg')
                      ? SafeSvgLogo(
                          key: ValueKey(item.logoUrl),
                          url: item.logoUrl!,
                          color: parseHexColor(item.logoHex) ?? Colors.grey[700]!,
                          fallbackLetter: item.name.isNotEmpty ? item.name.substring(0, 1).toUpperCase() : '?',
                        )
                      : Image.network(
                          item.logoUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            item.icon,
                            color: Colors.grey[700],
                          ),
                        ))
                  : Icon(item.icon, color: Colors.grey[700]),
            ),
          ),
          title: Text(item.name),
          subtitle: Text('${item.price.toStringAsFixed(2)} CHF'),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showEditDialog(context, ref, item);
              } else if (value == 'delete') {
                _showDeleteDialog(context, ref, item);
              } else if (value == 'toggle') {
                _toggleStatus(context, ref, item);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle',
                child: Text(
                  item.inactive == 0 ? 'Deaktivieren' : 'Aktivieren',
                  style: TextStyle(
                    color: item.inactive == 0 ? Colors.orange : Colors.green,
                  ),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'edit',
                child: Text('Bearbeiten'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Löschen', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
    );
  }
}
