import 'package:flutter/material.dart';
import 'services/wallos_settings_service.dart';
import 'services/wallos_connection_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await WallosSettingsService.loadSettings();
    setState(() {
      _tokenController.text = settings.token;
      _urlController.text = settings.url;
    });
  }

  Future<void> _saveSettings() async {
    await WallosSettingsService.saveSettings(
      url: _urlController.text,
      token: _tokenController.text,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Einstellungen erfolgreich gespeichert!')),
    );
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    final token = _tokenController.text.trim();

    if (url.isEmpty || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte URL und Token eingeben.')),
      );
      return;
    }

    // Zeige Loading-Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await WallosConnectionService.testConnection(
        url: url,
        token: token,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      final message = result.isSuccess
          ? 'Verbindung erfolgreich!\nStatus: ${result.statusCode}'
          : 'Verbindungsfehler!\nStatus: ${result.statusCode}';

      _showResultDialog(
        title: result.isSuccess ? '✓ Erfolg' : '✗ Fehler',
        message: message,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      _showResultDialog(
        title: '✗ Fehler',
        message: 'Verbindung fehlgeschlagen',
      );
    }
  }

  void _showResultDialog({
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Wallos API URL',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Wallos API Token',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _testConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Verbindung testen'),
                ),
                ElevatedButton(
                  onPressed: _saveSettings,
                  child: const Text('Speichern'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}





