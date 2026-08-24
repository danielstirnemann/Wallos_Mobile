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
            child: Align(
              alignment: Alignment.bottomLeft,
              // FittedBox skaliert den Titel automatisch etwas kleiner, falls
              // er auf schmalen Bildschirmen sonst nicht in den Drawer-Header
              // passen würde ("Dartisan SubTracker" ist deutlich länger als
              // das vorherige "Wallos").
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Dartisan SubTracker',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
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
