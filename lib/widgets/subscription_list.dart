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
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(content: Text(result['message'])),
              );
              if (result['success']) {
                Navigator.of(dialogContext).pop();
                await Future.delayed(const Duration(milliseconds: 500));
                ref.invalidate(subscriptionProvider);
              }
            }
          } catch (e) {
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
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
      builder: (context) => AlertDialog(
        title: const Text('Bestätigung'),
        content: Text('Möchtest du "${subscription.name}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final result = await SubscriptionCrudProvider.deleteSubscription(
                  baseUrl: baseUrl,
                  apiKey: apiKey,
                  id: subscription.id,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'])),
                  );
                  if (result['success']) {
                    await Future.delayed(const Duration(milliseconds: 500));
                    ref.invalidate(subscriptionProvider);
                  }
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
          subtitle: Text('${item.price} CHF'),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showEditDialog(context, ref, item);
              } else if (value == 'delete') {
                _showDeleteDialog(context, ref, item);
              }
            },
            itemBuilder: (context) => [
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
