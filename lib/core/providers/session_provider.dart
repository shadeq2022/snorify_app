import 'package:flutter/material.dart';
import 'package:snorify_app/core/database/database_helper.dart';
import 'package:snorify_app/core/models/sesi.dart';
import 'package:snorify_app/core/models/sensor_reading.dart';
import 'package:snorify_app/core/models/transaksi.dart';

class SessionProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // Current session
  Sesi? _currentSession;
  List<SensorReading> _currentReadings = [];
  List<Transaksi> _currentTransactions = [];
  
  // All sessions
  List<Sesi> _sessions = [];
  
  // Statistics
  double _averageSpO2 = 0.0;
  double _snoringPercentage = 0.0;
  int _totalSessions = 0;
  int _totalDuration = 0; // in minutes
  
  // Getters
  Sesi? get currentSession => _currentSession;
  List<SensorReading> get currentReadings => _currentReadings;
  List<Transaksi> get currentTransactions => _currentTransactions;
  List<Sesi> get sessions => _sessions;
  double get averageSpO2 => _averageSpO2;
  double get snoringPercentage => _snoringPercentage;
  int get totalSessions => _totalSessions;
  int get totalDuration => _totalDuration;
  
  // Initialize provider
  Future<void> initialize() async {
    await loadSessions();
    await loadStatistics();
  }
  
  // Load all sessions
  Future<void> loadSessions() async {
    _sessions = await _dbHelper.getSesiList();
    notifyListeners();
  }
  
  // Load session by ID
  Future<void> loadSessionById(int id) async {
    _currentSession = await _dbHelper.getSesiById(id);
    if (_currentSession != null) {
      await loadSessionData(id);
    }
    notifyListeners();
  }
  
  // Load session data (readings and transactions)
  Future<void> loadSessionData(int id) async {
    _currentReadings = await _dbHelper.getSensorReadingsBySesiId(id);
    _currentTransactions = await _dbHelper.getTransaksiBySesiId(id);
    _averageSpO2 = await _dbHelper.getAverageSpO2BySesiId(id);
    _snoringPercentage = await _dbHelper.getSnoringPercentageBySesiId(id);
    notifyListeners();
  }
  
  // Create new session
  Future<int> createSession(Sesi sesi) async {
    final id = await _dbHelper.insertSesi(sesi);
    await loadSessions();
    return id;
  }
  
  // Update session
  Future<void> updateSession(Sesi sesi) async {
    await _dbHelper.updateSesi(sesi);
    _currentSession = sesi;
    await loadSessions();
    notifyListeners();
  }
  
  // Delete session
  Future<void> deleteSession(int id) async {
    await _dbHelper.deleteSesi(id);
    if (_currentSession?.id == id) {
      _currentSession = null;
      _currentReadings = [];
      _currentTransactions = [];
    }
    await loadSessions();
    await loadStatistics();
    notifyListeners();
  }
  
  // Add sensor reading
  Future<void> addSensorReading(SensorReading reading) async {
    await _dbHelper.insertSensorReading(reading);
    _currentReadings.add(reading);
    notifyListeners();
  }

  // Get filtered readings excluding stabilization periods for statistics
  List<SensorReading> get filteredReadingsForStats {
    return _currentReadings.where((reading) => reading.stabilizing != 1).toList();
  }
  
  // Add transaction
  Future<void> addTransaction(Transaksi transaksi) async {
    await _dbHelper.insertTransaksi(transaksi);
    _currentTransactions.add(transaksi);
    notifyListeners();
  }
  
  // Update transaction
  Future<void> updateTransaction(Transaksi transaksi) async {
    await _dbHelper.updateTransaksi(transaksi);
    final index = _currentTransactions.indexWhere((t) => t.id == transaksi.id);
    if (index != -1) {
      _currentTransactions[index] = transaksi;
    }
    notifyListeners();
  }
  
  // Load statistics
  Future<void> loadStatistics() async {
    final stats = await _dbHelper.getStatistics();
    _totalSessions = stats['totalSessions'] ?? 0;
    _totalDuration = stats['totalDuration'] ?? 0;
    _averageSpO2 = stats['averageSpO2'] ?? 0.0;
    _snoringPercentage = stats['snoringPercentage'] ?? 0.0;
    notifyListeners();
  }
  
  // Get SpO2 data for charts
  List<Map<String, dynamic>> getSpO2ChartData() {
    return _currentReadings.map((reading) => {
      'timestamp': reading.timestamp,
      'value': reading.spo2,
    }).toList();
  }
  
  // Get snoring data for charts
  List<Map<String, dynamic>> getSnoringChartData() {
    return _currentReadings.map((reading) => {
      'timestamp': reading.timestamp,
      'value': reading.status,
    }).toList();
  }
  
  // Clear current session
  void clearCurrentSession() {
    _currentSession = null;
    _currentReadings = [];
    _currentTransactions = [];
    notifyListeners();
  }
  
  // Clear all data from the database
  Future<void> clearAllData() async {
    await _dbHelper.clearAllData();
    _sessions = [];
    _currentSession = null;
    _currentReadings = [];
    _currentTransactions = [];
    _averageSpO2 = 0.0;
    _snoringPercentage = 0.0;
    _totalSessions = 0;
    _totalDuration = 0;
    notifyListeners();
  }
}