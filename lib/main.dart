import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';
import 'main_drawer.dart';
import 'dashboard_page.dart';
import 'subscription_page.dart';
import 'settings_page.dart';
import 'widgets/gradient_appbar.dart';

void main() {
  runApp(
    const ProviderScope(
      child: WallosApp(),
    ),
  );
}

class WallosApp extends StatefulWidget {
  const WallosApp({super.key});

  @override
  State<WallosApp> createState() => _WallosAppState();
}

class _WallosAppState extends State<WallosApp> {
  int _currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: _buildPage(_currentPageIndex),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return _HomePage(onPageChanged: _changePage);
      case 1:
        return _SubscriptionPageWrapper(onPageChanged: _changePage);
      case 2:
        return _SettingsPageWrapper(onPageChanged: _changePage);
      default:
        return _HomePage(onPageChanged: _changePage);
    }
  }

  void _changePage(int index) {
    setState(() {
      _currentPageIndex = index;
    });
  }
}

class _HomePage extends StatelessWidget {
  final Function(int) onPageChanged;

  const _HomePage({required this.onPageChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Wallos',
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6366F1),
            const Color(0xFF8B5CF6),
          ],
        ),
        textColor: Colors.white,
        elevation: 8,
      ),
      drawer: MainDrawer(onPageChanged: onPageChanged),
      body: const DashboardPage(),
    );
  }
}

class _SubscriptionPageWrapper extends StatelessWidget {
  final Function(int) onPageChanged;

  const _SubscriptionPageWrapper({required this.onPageChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Abonnemente',
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6366F1),
            const Color(0xFF8B5CF6),
          ],
        ),
        textColor: Colors.white,
        elevation: 8,
        actions: [
          // Toggle Button
          Consumer(
            builder: (context, ref, child) {
              return IconButton(
                icon: const Icon(Icons.visibility),
                onPressed: () {},
              );
            },
          ),
          // Refresh Button
          Consumer(
            builder: (context, ref, child) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {},
              );
            },
          ),
        ],
      ),
      drawer: MainDrawer(onPageChanged: onPageChanged),
      body: const SubscriptionPage(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // FAB action
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SettingsPageWrapper extends StatelessWidget {
  final Function(int) onPageChanged;

  const _SettingsPageWrapper({required this.onPageChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Einstellungen',
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6366F1),
            const Color(0xFF8B5CF6),
          ],
        ),
        textColor: Colors.white,
        elevation: 8,
      ),
      drawer: MainDrawer(onPageChanged: onPageChanged),
      body: const SettingsPage(),
    );
  }
}
