import 'package:flutter/material.dart';
import '../models/subscription.dart';

class SubscriptionList extends StatelessWidget {
  final List<Subscription> subscriptions;

  const SubscriptionList({
    Key? key,
    required this.subscriptions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
          trailing: Text('${item.price} CHF'),
        );
      },
    );
  }
}
