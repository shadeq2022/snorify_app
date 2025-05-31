// App-wide constants

class AppConstants {
  // App information
  static const String appName = 'Snorify';
  static const String appVersion = '1.0.0';
  
  // BLE related constants
  // static const String deviceNamePrefix = 'ESP32'; // Prefix for ESP32C3 devices
  static const String esp32ServiceUuid = '12345678-1234-5678-1234-56789abcdef0';
    // Database related constants
  static const String dbName = 'snorify.db';
  static const int dbVersion = 3;
  
  // Table names
  static const String tableSesi = 'sesi';
  static const String tableSensorReading = 'sensor_reading';
  static const String tableTransaksi = 'transaksi';
  
  // JSON keys from ESP32C3
  static const String keyStatus = 'status';
  static const String keyTimestamp = 'timestamp';
  static const String keySpo2 = 'spo2';
  
  // Snoring status
  static const int statusNoSnore = 0;
  static const int statusSnore = 1;
  
  // SpO2 thresholds
  static const int spo2Normal = 95; // 95-100% is normal
  static const int spo2Warning = 90; // 90-94% is warning
  // Below 90% is danger
  
  // Routes
  static const String routeOnboarding = '/onboarding';
  static const String routeHome = '/home';
  static const String routeAddSession = '/add-session';
  static const String routeCreateSession = '/create-session';
  static const String routeDashboard = '/dashboard';
  static const String routeStatistics = '/statistics';
  static const String routeSessionDetail = '/session-detail';
  
  // BLE scan duration
  static const int scanDuration = 5; // Set to 10 seconds or any appropriate value
}