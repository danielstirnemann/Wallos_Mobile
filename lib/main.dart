import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';
import 'main_drawer.dart';
import 'dashboard_page.dart';

void main() {
  runApp(
    const ProviderScope(
      child: WallosApp(),
    ),
  );
}

class WallosApp extends StatelessWidget {
  const WallosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        drawer: const MainDrawer(),
        body: const DashboardPage(),
      ),
    );
  }
}
