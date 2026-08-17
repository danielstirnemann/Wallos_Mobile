import 'package:flutter/material.dart';
import 'models/subscription.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {

  final List<Subscription> subscriptions = [
    Subscription(name: 'Netflix', price: 17.99, icon: Icons.movie),
    Subscription(name: 'Spotify', price: 10.99, icon: Icons.music_note),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Abonnemente')),
      body: ListView.builder(
          itemCount: subscriptions.length,
          itemBuilder: (context, index){
            final item = subscriptions[index];
            return ListTile(
              title:Text(item.name),
              trailing: Text('${item.price} CHF'),
            );
          },
      ),
    );
  }
}
