import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription.dart';
import '../services/api_service.dart';

// Dieser Provider stellt die Liste der Abos bereit
final subscriptionProvider = FutureProvider<List<Subscription>>((ref) async {
  // Später rufen wir hier den ApiService auf:
  // return ref.read(apiServiceProvider).fetchSubscriptions();

  // Erstmal simulieren wir eine Verzögerung und geben Testdaten zurück:
  await Future.delayed(const Duration(seconds: 2));
  return [
    Subscription(name: 'Netflix', price: 17.99, icon: Icons.movie),
    Subscription(name: 'Spotify', price: 10.99, icon: Icons.music_note),
  ];
});