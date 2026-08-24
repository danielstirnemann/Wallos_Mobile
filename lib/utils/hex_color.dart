import 'package:flutter/material.dart';

/// Parst einen Hex-Farbstring (z.B. "#E50914" oder "E50914") zu einer
/// Flutter-[Color]. Gibt bei ungültiger oder fehlender Eingabe `null`
/// zurück.
Color? parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;

  var cleaned = hex.trim().replaceAll('#', '');
  if (cleaned.length == 6) {
    cleaned = 'FF$cleaned';
  }
  if (cleaned.length != 8) return null;

  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return null;
  return Color(value);
}
