import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// SQLite Database Manager
class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  static Database? _database;

  factory AppDatabase() {
    return _instance;
  }

  AppDatabase._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Initialisiert die Datenbank
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'wallos.db');

    final db = await openDatabase(
      path,
      version: 4,
      onCreate: _createTables,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 4) {
          await db.execute('DROP TABLE IF EXISTS subscriptions');
          await _createTables(db, newVersion);
        }
      },
    );

    // Einmalige Bereinigung: Durch einen früheren Bug wurde die remote_id
    // nach einem erfolgreichen Sync nicht am lokalen Eintrag gespeichert.
    // Beim nächsten Laden von der API wurde das Abo dadurch als komplett
    // neuer Eintrag erkannt und dupliziert. So ein verwaister Eintrag
    // (synced = 1, aber remote_id = NULL) kann mit der aktuellen Logik nicht
    // mehr entstehen und wird daher sicher entfernt.
    await _removeOrphanedDuplicates(db);

    return db;
  }

  Future<void> _removeOrphanedDuplicates(Database db) async {
    try {
      final deleted = await db.delete(
        'subscriptions',
        where: 'synced = 1 AND remote_id IS NULL',
      );
      if (deleted > 0) {
        // ignore: avoid_print
        print('[DB] $deleted verwaiste Duplikat(e) bereinigt');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[DB] Fehler bei der Duplikat-Bereinigung: $e');
    }
  }

  /// Erstellt Tabellen
  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE subscriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER UNIQUE,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        cycle INTEGER NOT NULL,
        frequency INTEGER DEFAULT 1,
        currency_id INTEGER,
        category_id INTEGER,
        payment_method_id INTEGER,
        inactive INTEGER DEFAULT 0,
        next_payment TEXT,
        logo_url TEXT,
        synced INTEGER DEFAULT 1
      )
    ''');
  }

  /// Speichert ein Abo (Lokal-First)
  Future<int> insertSubscription(dynamic subscription, {bool synced = true}) async {
    final db = await database;
    
    final map = {
      if (subscription.id != null && subscription.id > 0) 'id': subscription.id,
      'remote_id': subscription.remoteId,
      'name': subscription.name,
      'price': subscription.price,
      'cycle': subscription.cycle,
      'frequency': subscription.frequency,
      'currency_id': subscription.currencyId,
      'category_id': subscription.categoryId,
      'payment_method_id': subscription.paymentMethodId,
      'inactive': subscription.inactive,
      'next_payment': subscription.nextPayment,
      'logo_url': subscription.logoUrl,
      'synced': synced ? 1 : 0,
    };

    final id = await db.insert(
      'subscriptions',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('[DB] Abo gespeichert. ID: $id, Name: ${subscription.name}, Synced: $synced');
    return id;
  }

  /// Speichert mehrere Abos vom Server (API Import)
  Future<void> insertSubscriptions(List<dynamic> subscriptions) async {
    final db = await database;
    final batch = db.batch();
    
    print('[DB] Starte Import von ${subscriptions.length} Abos...');
    for (var sub in subscriptions) {
      final map = {
        'remote_id': sub.remoteId ?? sub.id,
        'name': sub.name,
        'price': sub.price,
        'cycle': sub.cycle,
        'frequency': sub.frequency,
        'currency_id': sub.currencyId,
        'category_id': sub.categoryId,
        'payment_method_id': sub.paymentMethodId,
        'inactive': sub.inactive,
        'next_payment': sub.nextPayment,
        'logo_url': sub.logoUrl,
        'synced': 1, // API Daten sind immer synced
      };

      batch.insert(
        'subscriptions',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    print('[DB] Import abgeschlossen.');
  }

  /// Gibt ein Abo nach ID zurück
  Future<dynamic?> getSubscriptionById(int id) async {
    final db = await database;
    final maps = await db.query(
      'subscriptions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return _mapToSubscription(maps.first);
    }
    return null;
  }

  /// Gibt alle aktiven Abos zurück
  Future<List<dynamic>> getAllActiveSubscriptions() async {
    final db = await database;
    final maps = await db.query(
      'subscriptions',
      where: 'inactive = ?',
      whereArgs: [0],
      orderBy: 'name ASC',
    );

    return maps.map((map) => _mapToSubscription(map)).toList();
  }

  /// Gibt alle inaktiven Abos zurück
  Future<List<dynamic>> getAllInactiveSubscriptions() async {
    final db = await database;
    final maps = await db.query(
      'subscriptions',
      where: 'inactive = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );

    return maps.map((map) => _mapToSubscription(map)).toList();
  }

  /// Gibt alle Abos zurück
  Future<List<dynamic>> getAllSubscriptions() async {
    final db = await database;
    final maps = await db.query(
      'subscriptions',
      orderBy: 'name ASC',
    );

    return maps.map((map) => _mapToSubscription(map)).toList();
  }

  /// Updated ein Abo
  Future<int> updateSubscription(dynamic subscription) async {
    final db = await database;
    
    final map = {
      'remote_id': subscription.remoteId,
      'name': subscription.name,
      'price': subscription.price,
      'cycle': subscription.cycle,
      'frequency': subscription.frequency,
      'currency_id': subscription.currencyId,
      'category_id': subscription.categoryId,
      'payment_method_id': subscription.paymentMethodId,
      'inactive': subscription.inactive,
      'next_payment': subscription.nextPayment,
      'logo_url': subscription.logoUrl,
    };

    return await db.update(
      'subscriptions',
      map,
      where: 'id = ?',
      whereArgs: [subscription.id],
    );
  }

  /// Löscht ein Abo
  Future<int> deleteSubscription(int id) async {
    final db = await database;
    return await db.delete(
      'subscriptions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Löscht alle Abos
  Future<int> deleteAllSubscriptions() async {
    final db = await database;
    return await db.delete('subscriptions');
  }

  /// Gibt Anzahl der Abos zurück
  Future<int> getSubscriptionCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM subscriptions');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Gibt alle ungesyncten (ausstehenden) Abos zurück
  Future<List<dynamic>> getPendingChanges() async {
    final db = await database;
    final maps = await db.query(
      'subscriptions',
      where: 'synced = ?',
      whereArgs: [0],
    );

    return maps.map((map) => _mapToSubscription(map)).toList();
  }

  /// Gibt Anzahl der ausstehenden Änderungen
  Future<int> getPendingChangesCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM subscriptions WHERE synced = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Markiert alle ausstehenden Änderungen als synced
  Future<void> markAllAsSynced() async {
    final db = await database;
    await db.update(
      'subscriptions',
      {'synced': 1},
      where: 'synced = ?',
      whereArgs: [0],
    );
  }

  /// Markiert ein spezifisches Abo als synced
  Future<void> markAsSynced(int id) async {
    final db = await database;
    await db.update(
      'subscriptions',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Markiert ein Abo als synced UND verknüpft es mit der von der API
  /// vergebenen remote_id. Ohne diese Verknüpfung würde das Abo beim
  /// nächsten Laden von der API als komplett neuer Eintrag erkannt und
  /// dupliziert werden, da "remote_id" sonst NULL bliebe.
  Future<void> markAsSyncedWithRemoteId(int id, int remoteId) async {
    final db = await database;
    await db.update(
      'subscriptions',
      {'synced': 1, 'remote_id': remoteId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Konvertiert eine Map zu Subscription
  dynamic _mapToSubscription(Map<String, dynamic> map) {
    return SubscriptionEntity(
      id: map['id'],
      remoteId: map['remote_id'],
      name: map['name'],
      price: map['price'] != null ? map['price'].toDouble() : 0.0,
      cycle: map['cycle'] ?? 1,
      frequency: map['frequency'] ?? 1,
      currencyId: map['currency_id'],
      categoryId: map['category_id'],
      paymentMethodId: map['payment_method_id'],
      inactive: map['inactive'] ?? 0,
      nextPayment: map['next_payment'] ?? '',
      logoUrl: map['logo_url'],
      synced: map['synced'] ?? 1,
    );
  }
}

/// Lokales Subscription Entity für Datenbank
class SubscriptionEntity {
  final int id;
  final int? remoteId;
  final String name;
  final double price;
  final int cycle;
  final int frequency;
  final int? currencyId;
  final int? categoryId;
  final int? paymentMethodId;
  final int inactive;
  final String nextPayment;
  final String? logoUrl;
  final int synced;

  SubscriptionEntity({
    required this.id,
    this.remoteId,
    required this.name,
    required this.price,
    required this.cycle,
    this.frequency = 1,
    this.currencyId,
    this.categoryId,
    this.paymentMethodId,
    required this.inactive,
    required this.nextPayment,
    this.logoUrl,
    required this.synced,
  });
}
