import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 1. Import
import 'providers/subscription_provider.dart';

// ConsumerWidget statt StatefulWidget nutzen
class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // subAsync bleibt hier!
    final subAsync = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Abonnemente')),
      body: RefreshIndicator(
        // Das lädt die Daten neu, wenn man zieht
        onRefresh: () => ref.refresh(subscriptionProvider.future),
        child: subAsync.when(
          data: (subscriptions) => ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(), // Wichtig für das Ziehen
            itemCount: subscriptions.length,
            itemBuilder: (context, index) {
              final item = subscriptions[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  foregroundImage: item.logoUrl != null
                      ? NetworkImage(item.logoUrl!)
                      : null,
                  onForegroundImageError: item.logoUrl != null
                      ? (exception, stackTrace) {}
                      : null,
                  child: Icon(item.icon, color: Colors.grey[700]),
                ),
                title: Text(item.name),
                trailing: Text('${item.price} CHF'),
              );
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => ListView( // ListView auch hier, damit man bei Fehlern ziehen kann
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
    );
  }
}