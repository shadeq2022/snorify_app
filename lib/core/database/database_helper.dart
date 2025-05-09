import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../constants/app_constants.dart';
import '../models/sesi.dart';
import '../models/sensor_reading.dart';
import '../models/transaksi.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), AppConstants.dbName);
    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create Sesi table
    await db.execute('''
      CREATE TABLE ${AppConstants.tableSesi} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT NOT NULL,
        tanggal TEXT NOT NULL,
        waktu_mulai TEXT NOT NULL,
        waktu_selesai TEXT,
        durasi INTEGER,
        device_id TEXT,
        catatan TEXT
      )
    ''');

    // Create Sensor Reading table
    await db.execute('''
      CREATE TABLE ${AppConstants.tableSensorReading} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sesi_id INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        spo2 INTEGER NOT NULL,
        status INTEGER NOT NULL,
        FOREIGN KEY (sesi_id) REFERENCES ${AppConstants.tableSesi} (id) ON DELETE CASCADE
      )
    ''');

    // Create Transaksi table
    await db.execute('''
      CREATE TABLE ${AppConstants.tableTransaksi} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sesi_id INTEGER NOT NULL,
        waktu_mulai TEXT NOT NULL,
        waktu_selesai TEXT,
        durasi INTEGER,
        FOREIGN KEY (sesi_id) REFERENCES ${AppConstants.tableSesi} (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
    if (oldVersion < 2) {
      // Add migrations for version 2
    }
  }

  // SESI OPERATIONS
  Future<int> insertSesi(Sesi sesi) async {
    Database db = await database;
    return await db.insert(AppConstants.tableSesi, sesi.toMap());
  }

  Future<List<Sesi>> getSesiList() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(AppConstants.tableSesi);
    return List.generate(maps.length, (i) => Sesi.fromMap(maps[i]));
  }

  Future<Sesi?> getSesiById(int id) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.tableSesi,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Sesi.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateSesi(Sesi sesi) async {
    Database db = await database;
    return await db.update(
      AppConstants.tableSesi,
      sesi.toMap(),
      where: 'id = ?',
      whereArgs: [sesi.id],
    );
  }

  Future<int> deleteSesi(int id) async {
    Database db = await database;
    return await db.delete(
      AppConstants.tableSesi,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // SENSOR READING OPERATIONS
  Future<int> insertSensorReading(SensorReading reading) async {
    Database db = await database;
    return await db.insert(AppConstants.tableSensorReading, reading.toMap());
  }

  Future<List<SensorReading>> getSensorReadingsBySesiId(int sesiId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.tableSensorReading,
      where: 'sesi_id = ?',
      whereArgs: [sesiId],
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) => SensorReading.fromMap(maps[i]));
  }

  // Get average SpO2 for a session
  Future<double> getAverageSpO2BySesiId(int sesiId) async {
    Database db = await database;
    final result = await db.rawQuery(
      'SELECT AVG(spo2) as avg_spo2 FROM ${AppConstants.tableSensorReading} WHERE sesi_id = ?',
      [sesiId],
    );
    return result.first['avg_spo2'] as double? ?? 0.0;
  }

  // Get snoring percentage for a session
  Future<double> getSnoringPercentageBySesiId(int sesiId) async {
    Database db = await database;
    final totalCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM ${AppConstants.tableSensorReading} WHERE sesi_id = ?',
      [sesiId],
    )) ?? 0;
    
    if (totalCount == 0) return 0.0;
    
    final snoringCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM ${AppConstants.tableSensorReading} WHERE sesi_id = ? AND status = ?',
      [sesiId, AppConstants.statusSnore],
    )) ?? 0;
    
    return (snoringCount / totalCount) * 100;
  }

  // TRANSAKSI OPERATIONS
  Future<int> insertTransaksi(Transaksi transaksi) async {
    Database db = await database;
    return await db.insert(AppConstants.tableTransaksi, transaksi.toMap());
  }

  Future<List<Transaksi>> getTransaksiBySesiId(int sesiId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.tableTransaksi,
      where: 'sesi_id = ?',
      whereArgs: [sesiId],
      orderBy: 'waktu_mulai ASC',
    );
    return List.generate(maps.length, (i) => Transaksi.fromMap(maps[i]));
  }

  Future<int> updateTransaksi(Transaksi transaksi) async {
    Database db = await database;
    return await db.update(
      AppConstants.tableTransaksi,
      transaksi.toMap(),
      where: 'id = ?',
      whereArgs: [transaksi.id],
    );
  }

  // Get statistics for all sessions
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await database;

    final totalSessions = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM ${AppConstants.tableSesi}'
    )) ?? 0;
    
    // Average SpO2 across all sessions
    final avgSpO2Result = await db.rawQuery(
      'SELECT AVG(spo2) as avg_spo2 FROM ${AppConstants.tableSensorReading}'
    );
    final avgSpO2 = avgSpO2Result.first['avg_spo2'] as double? ?? 0.0;
    
    // Total snoring percentage
    final totalReadings = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM ${AppConstants.tableSensorReading}'
    )) ?? 0;
    
    double snoringPercentage = 0.0;
    if (totalReadings > 0) {
      final snoringCount = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM ${AppConstants.tableSensorReading} WHERE status = ?',
        [AppConstants.statusSnore],
      )) ?? 0;
      
      snoringPercentage = (snoringCount / totalReadings) * 100;
    }
    
    return {
      'totalSessions': totalSessions,
      'avgSpO2': avgSpO2,
      'totalReadings': totalReadings,
      'snoringPercentage': snoringPercentage,
    };
  }

  // Clear all data from database
  Future<void> clearAllData() async {
    Database db = await database;
    await db.transaction((txn) async {
      await txn.delete(AppConstants.tableTransaksi);
      await txn.delete(AppConstants.tableSensorReading);
      await txn.delete(AppConstants.tableSesi);
    });
  }
}