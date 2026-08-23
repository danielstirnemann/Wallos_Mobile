import 'package:flutter/material.dart';

class Subscription {
  final int id;
  final int? remoteId;
  final String name;
  final double price;
  final int cycle;
  final int frequency;
  final int? currencyId;
  final int? categoryId;
  final int? paymentMethodId;
  final int inactive;
  final String nextPayment;
  final IconData? icon;
  final String? logoUrl;

  Subscription({
    required this.id,
    this.remoteId,
    required this.name,
    required this.price,
    required this.cycle,
    this.frequency = 1,
    this.currencyId,
    this.categoryId,
    this.paymentMethodId,
    required this.inactive,
    required this.nextPayment,
    this.icon,
    this.logoUrl,
  });

  factory Subscription.fromJson(Map<String, dynamic> json, {String baseUrl = ''}) {
    final logo = json['logo']?.toString();
    String? logoUrl;
    
    if (logo != null && logo.isNotEmpty) {
      if (logo.startsWith('http')) {
        // Wenn es bereits eine URL ist (Simple Icons), nutze sie direkt
        logoUrl = logo;
      } else if (baseUrl.isNotEmpty) {
        // Sonst hänge den Wallos-Pfad davor
        var cleanBaseUrl = baseUrl;
        if (cleanBaseUrl.endsWith('/')) {
          cleanBaseUrl = cleanBaseUrl.substring(0, cleanBaseUrl.length - 1);
        }
        logoUrl = '$cleanBaseUrl/images/uploads/logos/$logo';
      }
    }

    return Subscription(
      id: 0, // Platzhalter, wird vom Provider durch echte DB-ID ersetzt
      remoteId: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      name: json['name'] ?? 'Unbekannt',
      price: json['price'] != null ? double.tryParse(json['price'].toString()) ?? 0.0 : 0.0,
      cycle: json['cycle'] != null ? int.tryParse(json['cycle'].toString()) ?? 1 : 1,
      frequency: json['frequency'] != null ? int.tryParse(json['frequency'].toString()) ?? 1 : 1,
      currencyId: json['currency_id'] != null ? int.tryParse(json['currency_id'].toString()) : null,
      categoryId: json['category_id'] != null ? int.tryParse(json['category_id'].toString()) : null,
      paymentMethodId: json['payment_method_id'] != null ? int.tryParse(json['payment_method_id'].toString()) : null,
      inactive: json['inactive'] != null ? int.tryParse(json['inactive'].toString()) ?? 0 : 0,
      nextPayment: json['next_payment'] ?? '',
      icon: Icons.shopping_bag,
      logoUrl: logoUrl,
    );
  }
}
