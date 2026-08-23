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

  /// Sucht Logos nach Namen
  Future<List<LogoItem>> searchLogos(String query) async {
    final allLogos = await getAllLogos();

    if (query.isEmpty) {
      return allLogos;
    }

    final queryLower = query.toLowerCase();
    return allLogos
        .where(
          (logo) =>
              logo.name.toLowerCase().contains(queryLower) ||
              logo.slug.toLowerCase().contains(queryLower),
        )
        .toList();
  }

  /// Gibt Logo-URL zurück
  String getLogoUrl(String slug) {
    return 'https://cdn.jsdelivr.net/npm/simple-icons@v12/icons/$slug.svg';
  }

  /// Findet Logo nach Name
  Future<LogoItem?> findLogoByName(String name) async {
    final allLogos = await getAllLogos();
    try {
      return allLogos.firstWhere(
        (logo) => logo.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Findet Logo nach Slug
  Future<LogoItem?> findLogoBySlug(String slug) async {
    final allLogos = await getAllLogos();
    try {
      return allLogos.firstWhere(
        (logo) => logo.slug.toLowerCase() == slug.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }
}
