import 'package:flutter/material.dart';

class AppTheme {
  // Privater Getter für die Basis-Konfiguration der AppBar
  static AppBarTheme get _appBarTheme => const AppBarTheme(
    backgroundColor: Colors.indigo,
    foregroundColor: Colors.white,
    elevation: 2,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
  );

  // Öffentlicher Getter für das helle Theme
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    appBarTheme: _appBarTheme,
    colorSchemeSeed: Colors.indigo,
  );

  // Öffentlicher Getter für das dunkle Theme
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    appBarTheme: _appBarTheme.copyWith(
      backgroundColor: Colors.grey[900],
    ),
  );
}