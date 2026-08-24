# Backup & Wiederherstellung – Umsetzung

## Was wurde gemacht

### 1. Einstellungen wandern in die Datenbank
Bisher lagen die Wallos-Zugangsdaten (URL/Token) und die Standardwerte für
neue Abos in `SharedPreferences`. Für ein vollständiges Backup müssen sie
Teil derselben Datenquelle wie die Abos sein, daher:

- Neue Tabelle `app_settings` (Key-Value-Store) in der SQLite-Datenbank
  ([app_database.dart](file:///C:/Users/stirn/StudioProjects/Wallos_Mobile_dev/lib/database/app_database.dart)), DB-Version 6 → 7.
- [WallosSettingsService](file:///C:/Users/stirn/StudioProjects/Wallos_Mobile_dev/lib/services/wallos_settings_service.dart) und
  [DefaultSubscriptionSettingsService](file:///C:/Users/stirn/StudioProjects/Wallos_Mobile_dev/lib/services/default_subscription_settings_service.dart)
  lesen/schreiben jetzt aus der DB statt aus SharedPreferences.
- **Automatische Einmal-Migration**: Bestehende Installationen mit Werten in
  SharedPreferences werden beim ersten Zugriff automatisch in die DB
  übernommen – kein Datenverlust für existierende Nutzer.
- Alle bisherigen direkten SharedPreferences-Zugriffe auf die Wallos-Zugangsdaten
  (`subscription_provider.dart`, `meta_provider.dart`, `sync_service.dart`)
  wurden auf `WallosSettingsService.loadSettings()` umgestellt.

### 2. Neuer BackupService
[backup_service.dart](file:///C:/Users/stirn/StudioProjects/Wallos_Mobile_dev/lib/services/backup_service.dart) (neu):
- `buildBackupBytes()`: exportiert alle Einstellungen + alle lokal
  gespeicherten Abos (inkl. Sync-Status) als JSON-Datei (UTF-8-Bytes).
- `parseBackupBytes()`: validiert eine Backup-Datei.
- `restore()`: ersetzt Einstellungen + Abos vollständig durch den Inhalt
  des Backups.

### 3. UI in den Einstellungen
Neue Sektion "Backup & Wiederherstellung" in
[settings_page.dart](file:///C:/Users/stirn/StudioProjects/Wallos_Mobile_dev/lib/settings_page.dart):
- **Backup erstellen**: öffnet den System-Speichern-Dialog (`file_picker`),
  Dateiname z.B. `wallos_mobile_backup_2026-08-24T12-45-00.json`.
- **Wiederherstellen**: Datei auswählen → Sicherheitsabfrage (da alle
  aktuellen lokalen Daten überschrieben werden) → Wiederherstellung →
  alle betroffenen Provider werden automatisch neu geladen.

### 4. Neue Abhängigkeit
`file_picker: ^12.0.0` in `pubspec.yaml` ergänzt (plattformübergreifend:
Windows, Android, iOS, macOS, Linux).

## Getestet
- `flutter pub get` – erfolgreich.
- `flutter build windows --debug` – **erfolgreich gebaut**.
- `flutter build apk --debug` – schlägt in dieser Sandbox mit einem
  Gradle-Fehler fehl (`AndroidLocationsBuildService`), der **nichts mit
  dem Code zu tun hat** (tritt schon beim Anwenden des
  `com.android.application`-Plugins auf, bevor überhaupt Abhängigkeiten
  aufgelöst werden). Vermutlich eine Ressourcen-Sperre durch den parallel
  in der IDE laufenden Build/Run. Bitte direkt in Android Studio neu bauen.

> [!WARNING]
> Da ich keinen Bildschirmzugriff auf die laufende Windows-App habe, konnte
> ich die neue UI nicht visuell verifizieren. Bitte manuell testen (siehe
> unten).

## Manuell zu testen
1. App neu bauen/starten.
2. Einstellungen öffnen → ganz unten sollte die neue Sektion
   "Backup & Wiederherstellung" erscheinen.
3. "Backup erstellen" → Speicherort wählen → Datei sollte JSON mit
   `settings` und `subscriptions` enthalten.
4. Ein Abo hinzufügen/ändern, dann "Wiederherstellen" mit der zuvor
   erstellten Backup-Datei ausführen → Bestätigungsdialog bestätigen →
   der Zustand zum Zeitpunkt des Backups sollte wiederhergestellt sein
   (Abos UND Wallos-URL/Token/Standardwerte).
5. Bestehende Installation (falls vorhanden) prüfen: Zugangsdaten sollten
   nach dem Update weiterhin korrekt geladen werden (automatische Migration).
