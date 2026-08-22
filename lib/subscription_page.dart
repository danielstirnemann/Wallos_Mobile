import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/subscription_provider.dart';
import 'widgets/subscription_list.dart';

class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Abonnemente')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(subscriptionProvider.future),
        child: subAsync.when(
          data: (subscriptions) => SubscriptionList(subscriptions: subscriptions),
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
    );
  }
}