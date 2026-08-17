import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 1. Import
import 'providers/subscription_provider.dart';

// ConsumerWidget statt StatefulWidget nutzen
class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 2. Den Provider beobachten
    final subAsync = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Abonnemente')),
      // 3. Den Zustand (Laden, Daten, Fehler) behandeln
      body: subAsync.when(
        data: (subscriptions) => ListView.builder(
          itemCount: subscriptions.length,
          itemBuilder: (context, index) {
            final item = subscriptions[index];
            return ListTile(
              title: Text(item.name),
              trailing: Text('${item.price} CHF'),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Fehler: $err')),
      ),
    );
  }
}