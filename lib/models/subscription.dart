import 'package:flutter/material.dart';

class Subscription {
  final int id;
  final String name;
  final double price;
  final int cycle;  // 1=täglich, 3=monatlich, 4=quartalsweise, 12=jährlich, etc.
  final int inactive;  // 0=aktiv, 1=inaktiv
  final String nextPayment;  // Datum der nächsten Zahlung (YYYY-MM-DD)
  final IconData icon;
  final String? logoUrl;

  Subscription({
    required this.id,
    required this.name,
    required this.price,
    required this.cycle,
    required this.inactive,
    required this.nextPayment,
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
      cycle: json['cycle'] ?? 12,  // Default: jährlich
      inactive: json['inactive'] ?? 0,  // 0=aktiv, 1=inaktiv
      nextPayment: json['next_payment'] ?? '',
      icon: Icons.account_balance_wallet,
      logoUrl: logoUrl,
    );
  }
}
