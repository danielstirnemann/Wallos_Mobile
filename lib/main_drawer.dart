import 'package:flutter/material.dart';

class MainDrawer extends StatelessWidget {
  final Function(int)? onPageChanged;

  const MainDrawer({super.key, this.onPageChanged});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6366F1),
                  Color(0xFF8B5CF6),
                ],
              ),
            ),
            child: Text(
              'Wallos',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          // Home - zuoberst
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              onPageChanged?.call(0);
            },
          ),
          const Divider(),
          // Andere Menüpunkte
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: const Text('Abonnemente'),
            onTap: () {
              Navigator.pop(context);
              onPageChanged?.call(1);
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Einstellungen'),
            onTap: () {
              Navigator.pop(context);
              onPageChanged?.call(2);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profil'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
