import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/default_subscription_settings_provider.dart';
import 'providers/meta_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/sync_provider.dart';
import 'services/backup_service.dart';
import 'services/default_subscription_settings_service.dart';
import 'services/subscription_crud_service.dart';
import 'services/wallos_settings_service.dart';
import 'services/wallos_connection_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  // Standardwerte für neue Abos ("Abo hinzufügen"-Dialog).
  int? _defaultCurrencyId;
  int? _defaultCategoryId;
  int? _defaultPaymentMethodId;
  int? _defaultPayerUserId;
  int _defaultCycle = 3; // 3 = Monatlich
  bool _defaultsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadDefaultSubscriptionSettings();
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

  Future<void> _loadDefaultSubscriptionSettings() async {
    final defaults = await DefaultSubscriptionSettingsService.loadSettings();
    setState(() {
      _defaultCurrencyId = defaults.currencyId;
      _defaultCategoryId = defaults.categoryId;
      _defaultPaymentMethodId = defaults.paymentMethodId;
      _defaultPayerUserId = defaults.payerUserId;
      _defaultCycle = defaults.cycle;
      _defaultsLoaded = true;
    });
  }

  Future<void> _saveDefaultSubscriptionSettings() async {
    await DefaultSubscriptionSettingsService.saveSettings(
      currencyId: _defaultCurrencyId,
      categoryId: _defaultCategoryId,
      paymentMethodId: _defaultPaymentMethodId,
      payerUserId: _defaultPayerUserId,
      cycle: _defaultCycle,
    );

    // Der "Abo hinzufügen"-Dialog liest diese Standardwerte über den
    // Provider - beim nächsten Öffnen sollen die neuen Werte gelten.
    ref.invalidate(defaultSubscriptionSettingsProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Standardwerte für neue Abos gespeichert!')),
    );
  }

  Future<void> _saveSettings() async {
    final newUrl = _urlController.text.trim();
    final newToken = _tokenController.text.trim();

    // Aktuell gespeicherte Zugangsdaten laden, um einen Account-/Server-
    // Wechsel zu erkennen (nicht die evtl. schon geänderten Textfelder).
    final current = await WallosSettingsService.loadSettings();
    final hadExistingCredentials = current.url.isNotEmpty && current.token.isNotEmpty;
    final isAccountSwitch = hadExistingCredentials &&
        (current.url != newUrl || current.token != newToken);

    if (isAccountSwitch) {
      final confirmed = await _confirmAccountSwitch();
      if (confirmed != true) {
        return; // Abgebrochen: alte Einstellungen bleiben unverändert
      }

      // Lokale Abo-Daten gehören zum ALTEN Account/Server. Da Wallos-IDs
      // ("remote_id") pro Instanz vergeben werden, können sie mit denen
      // eines anderen Accounts kollidieren (z.B. UNIQUE-Constraint-Fehler
      // beim nächsten Sync) oder einfach veraltete Daten anzeigen. Daher
      // werden sie beim Wechsel gelöscht.
      //
      // WICHTIG: Das löscht NUR die lokale SQLite-Kopie auf dem Gerät.
      // Es wird dabei KEIN API-Aufruf getätigt - im Wallos-Webinterface
      // (egal ob altem oder neuem Account) ändert sich dadurch nichts.
      await SubscriptionCrudService().clearAllLocalData();
    }

    await WallosSettingsService.saveSettings(
      url: newUrl,
      token: newToken,
    );

    if (isAccountSwitch) {
      // UI zwingen, alles neu vom (neuen) Account zu laden. Beides sind
      // reine Lese-Operationen (GET von der API bzw. lokale DB-Abfrage) -
      // "syncProvider" (welches tatsächlich Abos zur API hochladen/löschen
      // würde) wird hier bewusst NICHT ausgelöst.
      ref.invalidate(subscriptionProvider);
      ref.invalidate(pendingChangesCountProvider);
      ref.invalidate(metaDataProvider);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isAccountSwitch
              ? 'Einstellungen gespeichert. Lokale Abo-Daten wurden für den Account-Wechsel geleert.'
              : 'Einstellungen erfolgreich gespeichert!',
        ),
      ),
    );
  }

  Future<bool?> _confirmAccountSwitch() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wallos-Verbindung ändern?'),
        content: const Text(
          'Die URL oder der Token unterscheiden sich von der aktuell verbundenen '
          'Wallos-Instanz. Damit Abos zwischen Accounts nicht vermischt werden, '
          'werden dabei alle lokal zwischengespeicherten Abos gelöscht und beim '
          'nächsten Laden frisch vom neuen Account geholt.\n\n'
          'Noch nicht synchronisierte Änderungen für den alten Account gehen dabei verloren.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Fortfahren', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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

  /// Erstellt ein Backup ALLER lokalen App-Daten (Einstellungen + Abos) und
  /// lässt den Nutzer per System-Dialog wählen, wo die Datei gespeichert
  /// werden soll.
  Future<void> _createBackup() async {
    try {
      final bytes = await BackupService().buildBackupBytes();
      final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');

      final outputPath = await FilePicker.saveFile(
        dialogTitle: 'Backup speichern',
        fileName: 'wallos_mobile_backup_$timestamp.json',
        bytes: bytes,
      );

      if (!mounted) return;
      if (outputPath == null) {
        return; // Nutzer hat abgebrochen
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup erfolgreich erstellt.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup fehlgeschlagen: $e')),
      );
    }
  }

  /// Lässt den Nutzer eine zuvor exportierte Backup-Datei auswählen und
  /// stellt nach einer Sicherheitsabfrage ALLE lokalen Einstellungen + Abos
  /// daraus wieder her.
  Future<void> _restoreBackup() async {
    PlatformFile? file;
    try {
      file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Datei konnte nicht geöffnet werden: $e')),
      );
      return;
    }
    if (file == null) return; // Nutzer hat abgebrochen

    Map<String, dynamic> data;
    try {
      final Uint8List bytes = await file.readAsBytes();
      data = BackupService().parseBackupBytes(bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ungültige Backup-Datei: $e')),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup wiederherstellen?'),
        content: const Text(
          'Dadurch werden ALLE aktuellen lokalen Daten (Einstellungen und Abos) '
          'durch den Inhalt der Backup-Datei ersetzt. Noch nicht synchronisierte '
          'Änderungen gehen dabei unwiderruflich verloren.\n\n'
          'Fortfahren?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Wiederherstellen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await BackupService().restore(data);

      // Lokale UI-Felder + alle betroffenen Provider neu laden, damit die
      // wiederhergestellten Daten sofort überall sichtbar sind.
      await _loadSettings();
      await _loadDefaultSubscriptionSettings();
      ref.invalidate(subscriptionProvider);
      ref.invalidate(pendingChangesCountProvider);
      ref.invalidate(metaDataProvider);
      ref.invalidate(defaultSubscriptionSettingsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wiederherstellung abgeschlossen.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wiederherstellung fehlgeschlagen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _testConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Verbindung testen', textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  child: const Text('Speichern'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Standardwerte für neue Abos',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Diese Werte werden im "Abo hinzufügen"-Dialog automatisch vorausgewählt.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _buildDefaultsSection(),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Backup & Wiederherstellung',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Sichert alle lokalen App-Daten (Einstellungen und Abos) in einer '
            'Datei bzw. stellt sie daraus wieder her. Betrifft NICHT die Daten '
            'auf deinem Wallos-Server.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _createBackup,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Backup erstellen'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _restoreBackup,
                  icon: const Icon(Icons.download_for_offline),
                  label: const Text('Wiederherstellen'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultsSection() {
    if (!_defaultsLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final metaAsync = ref.watch(metaDataProvider);

    return metaAsync.when(
      data: (meta) {
        // Falls die zuvor konfigurierte Standardauswahl in der JETZT
        // verfügbaren Liste nicht mehr existiert (z.B. eine lokale
        // Standard-Währung/-Kategorie von VOR dem Verbinden mit Wallos, oder
        // ein Eintrag, der auf dem Wallos-Server zwischenzeitlich gelöscht
        // wurde), muss sie zurücksetzt werden - sonst würde das
        // DropdownButtonFormField versuchen, einen nicht vorhandenen Wert
        // darzustellen.
        if (_defaultCurrencyId != null && !meta.currencies.any((c) => c.id == _defaultCurrencyId)) {
          _defaultCurrencyId = null;
        }
        if (_defaultCategoryId != null && !meta.categories.any((c) => c.id == _defaultCategoryId)) {
          _defaultCategoryId = null;
        }
        if (_defaultPaymentMethodId != null && !meta.paymentMethods.any((pm) => pm.id == _defaultPaymentMethodId)) {
          _defaultPaymentMethodId = null;
        }
        if (_defaultPayerUserId != null && !meta.householdMembers.any((m) => m.id == _defaultPayerUserId)) {
          _defaultPayerUserId = null;
        }

        if (meta.currencies.isEmpty && meta.categories.isEmpty && meta.paymentMethods.isEmpty) {
          return const Text(
            'Bitte zuerst eine gültige Wallos-Verbindung speichern, um Währung, '
            'Kategorie und Zahlungsmethode als Standard auswählen zu können.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (meta.currencies.isNotEmpty) ...[
              DropdownButtonFormField<int?>(
                // WICHTIG: Erzwingt einen frischen FormField-State, sobald
                // sich die verfügbare Währungsliste ändert (z.B. Wechsel von
                // lokalen Standard-Währungen zu den echten Wallos-Währungen
                // nach dem Verbinden) - "initialValue" wird sonst NUR beim
                // allerersten Aufbau des Widgets berücksichtigt.
                key: ValueKey('currency-${meta.currencies.map((c) => c.id).join(',')}'),
                initialValue: _defaultCurrencyId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Standard-Währung',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Keine Vorauswahl')),
                  ...meta.currencies.map((c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(
                          '${c.name} (${c.symbol})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
                onChanged: (value) => setState(() => _defaultCurrencyId = value),
              ),
              const SizedBox(height: 16),
            ],
            if (meta.categories.isNotEmpty) ...[
              DropdownButtonFormField<int?>(
                key: ValueKey('category-${meta.categories.map((c) => c.id).join(',')}'),
                initialValue: _defaultCategoryId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Standard-Kategorie',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Keine Vorauswahl')),
                  ...meta.categories.map((c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (value) => setState(() => _defaultCategoryId = value),
              ),
              const SizedBox(height: 16),
            ],
            if (meta.paymentMethods.isNotEmpty) ...[
              DropdownButtonFormField<int?>(
                key: ValueKey('payment_method-${meta.paymentMethods.map((pm) => pm.id).join(',')}'),
                initialValue: _defaultPaymentMethodId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Standard-Zahlungsmethode',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Keine Vorauswahl')),
                  ...meta.paymentMethods.map((pm) => DropdownMenuItem<int?>(
                        value: pm.id,
                        child: Text(pm.name, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (value) => setState(() => _defaultPaymentMethodId = value),
              ),
              const SizedBox(height: 16),
            ],
            if (meta.householdMembers.isNotEmpty) ...[
              DropdownButtonFormField<int?>(
                key: ValueKey('payer-${meta.householdMembers.map((m) => m.id).join(',')}'),
                initialValue: _defaultPayerUserId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Standard-Zahler',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Keine Vorauswahl')),
                  ...meta.householdMembers.map((m) => DropdownMenuItem<int?>(
                        value: m.id,
                        child: Text(m.name, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (value) => setState(() => _defaultPayerUserId = value),
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<int>(
              initialValue: _defaultCycle,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Standard-Zyklus',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Täglich')),
                DropdownMenuItem(value: 2, child: Text('Wöchentlich')),
                DropdownMenuItem(value: 3, child: Text('Monatlich')),
                DropdownMenuItem(value: 4, child: Text('Jährlich')),
                DropdownMenuItem(value: 5, child: Text('Einmalig')),
              ],
              onChanged: (value) => setState(() => _defaultCycle = value ?? 3),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _saveDefaultSubscriptionSettings,
                child: const Text('Standardwerte speichern'),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Fehler beim Laden der Wallos-Daten: $err'),
    );
  }
}
