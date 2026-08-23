import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription.dart';
import '../providers/subscription_crud_provider.dart';
import '../providers/subscription_provider.dart';
import 'subscription_form_dialog.dart';

class SubscriptionList extends ConsumerWidget {
  final List<Subscription> subscriptions;
  final String baseUrl;
  final String apiKey;
  final RefreshCallback onRefresh;

  const SubscriptionList({
    super.key,
    required this.subscriptions,
    required this.baseUrl,
    required this.apiKey,
    required this.onRefresh,
  });

  void _toggleStatus(BuildContext context, WidgetRef ref, Subscription subscription) async {
    try {
      final result = await SubscriptionCrudProvider.toggleInactiveStatus(
        baseUrl: baseUrl,
        apiKey: apiKey,
        id: subscription.id,
        currentInactiveStatus: subscription.inactive,
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
        
        if (result['success']) {
          // ignore: unused_result
          ref.refresh(subscriptionProvider);
        }
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
            final result = await SubscriptionCrudProvider.editSubscription(
              baseUrl: baseUrl,
              apiKey: apiKey,
              id: subscription.id,
              name: data['name'],
              price: data['price'],
              currencyId: data['currency_id'],
              cycle: data['cycle'],
              frequency: data['frequency'],
              nextPayment: data['next_payment'],
              categoryId: data['category_id'] as int?,
              paymentMethodId: data['payment_method_id'] as int?,
            );
            
            // Dialog schließen ZUERST
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
            
            // Dann SnackBar
            if (context.mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result['message'])),
              );
            }
            
            // Dann Refresh
            if (result['success']) {
              // ignore: unused_result
              ref.refresh(subscriptionProvider);
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
                final result = await SubscriptionCrudProvider.deleteSubscription(
                  baseUrl: baseUrl,
                  apiKey: apiKey,
                  id: subscription.id,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'])),
                  );
                  if (result['success']) {
                    print('Abo gelöscht - starte Refresh...');
                    // ignore: unused_result
                    ref.refresh(subscriptionProvider);
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
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
              color: Colors.transparent,
              padding: const EdgeInsets.all(4),
              child: item.logoUrl != null
                  ? Image.network(
                      item.logoUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        item.icon,
                        color: Colors.grey[700],
                      ),
                    )
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
