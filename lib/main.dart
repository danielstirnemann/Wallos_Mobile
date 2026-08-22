import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';
import 'main_drawer.dart';

void main () {
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
      //darkTheme: AppTheme.darkTheme,
      home: Scaffold(
        appBar: AppBar(
            title: Text("Home")
        ),
        drawer: const MainDrawer(),
        body: ListView(
          children: const [
            ListTile(title: Text("Meine Abos")),
            ListTile(title: Text("Netflix")),
          ],
        ),
      ),
    );
  }
}
