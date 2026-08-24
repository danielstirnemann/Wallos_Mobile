import '../models/category.dart';
import '../models/currency.dart';

/// Eingebaute Standard-Währungen und -Kategorien, die IMMER lokal verfügbar
/// sind - unabhängig davon, ob eine Wallos-Verbindung konfiguriert ist oder
/// der Wallos-Server gerade erreichbar ist. Damit kann die App auch komplett
/// eigenständig (offline, ohne jemals eine Wallos-Instanz verbunden zu
/// haben) zum Verwalten von Abos genutzt werden.
///
/// WICHTIG: Die IDs sind bewusst NEGATIV, um sie eindeutig von echten
/// Wallos-IDs (immer positiv) unterscheiden zu können. Der SyncService
/// erkennt daran, dass eine currency_id/category_id NICHT von einer
/// tatsächlich verbundenen Wallos-Instanz stammt, und schickt sie beim
/// Hochladen NICHT direkt als ID mit (das würde die Wallos-Validierung
/// "Invalid currency/category ID" auslösen) - siehe SyncService.

/// Entspricht den Kategorien, die Wallos selbst bei der Registrierung eines
/// neuen Nutzers anlegt (siehe registration.php), damit Nutzer offline
/// dieselbe vertraute Auswahl erhalten.
final List<WallosCategory> defaultLocalCategories = [
  WallosCategory(id: -1, name: 'Keine Kategorie'),
  WallosCategory(id: -2, name: 'Unterhaltung'),
  WallosCategory(id: -3, name: 'Musik'),
  WallosCategory(id: -4, name: 'Nebenkosten'),
  WallosCategory(id: -5, name: 'Essen & Getränke'),
  WallosCategory(id: -6, name: 'Gesundheit & Wohlbefinden'),
  WallosCategory(id: -7, name: 'Produktivität'),
  WallosCategory(id: -8, name: 'Banking'),
  WallosCategory(id: -9, name: 'Transport'),
  WallosCategory(id: -10, name: 'Bildung'),
  WallosCategory(id: -11, name: 'Versicherung'),
  WallosCategory(id: -12, name: 'Gaming'),
  WallosCategory(id: -13, name: 'News & Magazine'),
  WallosCategory(id: -14, name: 'Software'),
  WallosCategory(id: -15, name: 'Technologie'),
  WallosCategory(id: -16, name: 'Cloud-Dienste'),
  WallosCategory(id: -17, name: 'Spenden & Wohltätigkeit'),
];

/// Eine kleine, aber breit abgedeckte Auswahl gängiger Weltwährungen.
final List<WallosCurrency> defaultLocalCurrencies = [
  WallosCurrency(id: -1, name: 'US-Dollar', symbol: r'$'),
  WallosCurrency(id: -2, name: 'Euro', symbol: '€'),
  WallosCurrency(id: -3, name: 'Schweizer Franken', symbol: 'CHF'),
  WallosCurrency(id: -4, name: 'Britisches Pfund', symbol: '£'),
  WallosCurrency(id: -5, name: 'Japanischer Yen', symbol: '¥'),
  WallosCurrency(id: -6, name: 'Kanadischer Dollar', symbol: r'CA$'),
  WallosCurrency(id: -7, name: 'Australischer Dollar', symbol: r'AU$'),
  WallosCurrency(id: -8, name: 'Chinesischer Yuan', symbol: '¥'),
  WallosCurrency(id: -9, name: 'Indische Rupie', symbol: '₹'),
  WallosCurrency(id: -10, name: 'Schwedische Krone', symbol: 'kr'),
  WallosCurrency(id: -11, name: 'Norwegische Krone', symbol: 'kr'),
  WallosCurrency(id: -12, name: 'Polnischer Złoty', symbol: 'zł'),
  WallosCurrency(id: -13, name: 'Brasilianischer Real', symbol: r'R$'),
  WallosCurrency(id: -14, name: 'Mexikanischer Peso', symbol: r'$'),
  WallosCurrency(id: -15, name: 'Südafrikanischer Rand', symbol: 'R'),
];
