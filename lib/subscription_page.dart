import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/subscription_provider.dart';
import 'providers/subscription_crud_provider.dart';
import 'widgets/subscription_list.dart';
import 'widgets/subscription_form_dialog.dart';

class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  void _showAddDialog(BuildContext context, WidgetRef ref, String baseUrl, String apiKey) {
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
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(content: Text(result['message'])),
              );
              if (result['success']) {
                print('Abo erfolgreich hinzugefügt, schließe Dialog...');
                // Schließe den Dialog
                Navigator.of(dialogContext).pop();
                // Warte und aktualisiere die Liste
                await Future.delayed(const Duration(seconds: 1));
                print('Invalidiere subscriptionProvider...');
                ref.invalidate(subscriptionProvider);
              }
            }
          } catch (e) {
            print('Fehler beim Hinzufügen: $e');
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(subscriptionProvider);

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, prefs) {
        final baseUrl = (prefs.data?.getString('wallos_api_url') ?? '').trim();
        final apiKey = (prefs.data?.getString('wallos_api_token') ?? '').trim();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Abonnemente'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.refresh(subscriptionProvider),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => ref.refresh(subscriptionProvider.future),
            child: subAsync.when(
              data: (subscriptions) => SubscriptionList(
                subscriptions: subscriptions,
                baseUrl: baseUrl,
                apiKey: apiKey,
                onRefresh: () async => ref.refresh(subscriptionProvider.future),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.8,
                    child: Center(child: Text('Fehler: $err')),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddDialog(context, ref, baseUrl, apiKey),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}