import 'dart:convert';
import 'dart:typed_data';
import '../database/app_database.dart';

/// Erstellt und liest Backups aller lokalen App-Daten (Einstellungen +
/// Abonnemente), damit der Zustand der App vollständig gesichert und später
/// wiederhergestellt werden kann - z.B. bei einem Gerätewechsel oder nach
/// einer Neuinstallation.
///
/// WICHTIG: Ein Backup enthält NUR lokale Daten. Es handelt sich NICHT um
/// ein Server-seitiges Wallos-Backup - die Daten auf dem Wallos-Server
/// selbst sind davon nicht betroffen.
class BackupService {
  static const int backupFormatVersion = 1;

  final AppDatabase _db;

  BackupService({AppDatabase? db}) : _db = db ?? AppDatabase();

  /// Baut das Backup als JSON-serialisierbare Map (Einstellungen + alle
  /// lokal gespeicherten Abos inkl. Sync-Status).
  Future<Map<String, dynamic>> buildBackup() async {
    final settings = await _db.getAllSettings();
    final subscriptions = await _db.getAllSubscriptionsRaw();

    return {
      'formatVersion': backupFormatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settings,
      'subscriptions': subscriptions,
    };
  }

  /// Wie [buildBackup], aber direkt als UTF-8-kodierte Bytes (z.B. für
  /// FilePicker.saveFile, welches die Bytes direkt entgegennimmt - das
  /// funktioniert plattformübergreifend auch auf Android ohne zusätzliche
  /// Speicher-Berechtigungen).
  Future<Uint8List> buildBackupBytes() async {
    final backup = await buildBackup();
    final jsonString = const JsonEncoder.withIndent('  ').convert(backup);
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  /// Liest & validiert eine zuvor exportierte Backup-Datei (als Bytes).
  /// Wirft eine [FormatException], falls die Datei kein gültiges Backup ist.
  Map<String, dynamic> parseBackupBytes(Uint8List bytes) {
    final Object? data;
    try {
      data = json.decode(utf8.decode(bytes));
    } catch (_) {
      throw const FormatException('Die Datei enthält kein gültiges JSON.');
    }

    if (data is! Map || data['settings'] is! Map || data['subscriptions'] is! List) {
      throw const FormatException('Ungültige Backup-Datei (unerwartetes Format).');
    }

    return Map<String, dynamic>.from(data);
  }

  /// Stellt Einstellungen + Abos aus einem zuvor gelesenen/validierten
  /// Backup wieder her.
  ///
  /// ACHTUNG: Dies ÜBERSCHREIBT ALLE aktuell lokal gespeicherten
  /// Einstellungen und Abos unwiderruflich (inkl. noch nicht
  /// synchronisierter Änderungen).
  Future<void> restore(Map<String, dynamic> backup) async {
    final rawSettings = backup['settings'] as Map;
    final settings = <String, String>{
      for (final entry in rawSettings.entries) entry.key.toString(): entry.value.toString(),
    };

    final rawSubscriptions = backup['subscriptions'] as List;
    final subscriptions = rawSubscriptions
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    await _db.replaceAllSettings(settings);
    await _db.replaceAllSubscriptions(subscriptions);
  }
}
