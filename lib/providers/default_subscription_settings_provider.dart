import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/default_subscription_settings_service.dart';

/// Stellt die in den Einstellungen konfigurierten Standardwerte für neue
/// Abos bereit (z.B. für das "Abo hinzufügen"-Formular).
final defaultSubscriptionSettingsProvider = FutureProvider<DefaultSubscriptionSettings>((ref) async {
  return DefaultSubscriptionSettingsService.loadSettings();
});
