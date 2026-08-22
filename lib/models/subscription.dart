import 'package:flutter/material.dart';

class Subscription {
  final int id;
  final String name;
  final double price;
  final IconData icon;
  final String? logoUrl;

  Subscription({
    required this.id,
    required this.name,
    required this.price,
    required this.icon,
    this.logoUrl,
  });

  factory Subscription.fromJson(Map<String, dynamic> json, {String baseUrl = ''}) {
    final logo = json['logo'];
    String? logoUrl;
    if (logo != null && logo.toString().isNotEmpty && baseUrl.isNotEmpty) {
      logoUrl = '$baseUrl/images/uploads/logos/$logo';
    }

    return Subscription(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unbekannt',
      price: (json['price'] as num).toDouble(),
      icon: Icons.account_balance_wallet,
      logoUrl: logoUrl,
    );
  }
}
