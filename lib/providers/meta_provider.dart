import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category.dart';
import '../models/currency.dart';
import '../models/payment_method.dart';

class MetaData {
  final List<WallosCategory> categories;
  final List<WallosCurrency> currencies;
  final List<WallosPaymentMethod> paymentMethods;

  MetaData({
    required this.categories,
    required this.currencies,
    required this.paymentMethods,
  });
}

final metaDataProvider = FutureProvider<MetaData>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  var url = (prefs.getString('wallos_api_url') ?? '').trim();
  final token = (prefs.getString('wallos_api_token') ?? '').trim();

  if (url.isEmpty || token.isEmpty) return MetaData(categories: [], currencies: [], paymentMethods: []);
  if (url.endsWith('/')) url = url.substring(0, url.length - 1);

  Future<List<T>> fetch<T>(String endpoint, String key, T Function(Map<String, dynamic>) fromJson) async {
    final response = await http.get(Uri.parse('$url/api/$endpoint?api_key=$token'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return (data[key] as List).map((i) => fromJson(i)).toList();
      }
    }
    return [];
  }

  final results = await Future.wait([
    fetch('categories/get_categories.php', 'categories', (j) => WallosCategory.fromJson(j)),
    fetch('currencies/get_currencies.php', 'currencies', (j) => WallosCurrency.fromJson(j)),
    fetch('payment_methods/get_payment_methods.php', 'payment_methods', (j) => WallosPaymentMethod.fromJson(j)),
  ]);

  return MetaData(
    categories: results[0] as List<WallosCategory>,
    currencies: results[1] as List<WallosCurrency>,
    paymentMethods: results[2] as List<WallosPaymentMethod>,
  );
});
