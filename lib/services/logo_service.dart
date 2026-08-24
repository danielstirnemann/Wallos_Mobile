import 'dart:convert';
import 'package:flutter/services.dart';

/// Logo Model
class LogoItem {
  final String name;
  final String slug;
  final String hex;
  late final String url;

  LogoItem({
    required this.name,
    required this.slug,
    required this.hex,
  }) {
    url = 'https://cdn.jsdelivr.net/npm/simple-icons@v12/icons/$slug.svg';
  }

  factory LogoItem.fromJson(Map<String, dynamic> json) {
    return LogoItem(
      name: json['name'] ?? 'Unknown',
      slug: json['slug'] ?? '',
      hex: json['hex'] ?? '#000000',
    );
  }
}

/// Logo Service - Verwaltet Logo-Suche und Caching
class LogoService {
  static final LogoService _instance = LogoService._internal();
  static List<LogoItem>? _cachedLogos;

  factory LogoService() {
    return _instance;
  }

  LogoService._internal();

  /// Lädt alle verfügbaren Logos
  Future<List<LogoItem>> getAllLogos() async {
    if (_cachedLogos != null) {
      return _cachedLogos!;
    }

    try {
      // Lade aus assets/logos.json
      final jsonString = await rootBundle.loadString('assets/logos.json');
      final jsonData = json.decode(jsonString) as List<dynamic>;

      _cachedLogos = jsonData
          .map((item) => LogoItem.fromJson(item as Map<String, dynamic>))
          .toList();

      print('[LogoService] ${_cachedLogos!.length} Logos geladen');
      return _cachedLogos!;
    } catch (e) {
      print('[LogoService] Fehler beim Laden: $e');
      return [];
    }
  }

}
