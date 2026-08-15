import 'package:flutter/material.dart';
import 'app_theme.dart';

void main () => runApp(WallosApp());

class WallosApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        appBar: AppBar(
            title: Text("Wallos")
        ),
        body: ListView(children: [Text("Meine Abos"), Text("Netflix")]),
      ),
    );
  }
}
