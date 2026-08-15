import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'main_drawer.dart';

void main () => runApp(WallosApp());

class WallosApp extends StatelessWidget {
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
