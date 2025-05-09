class SensorReading {
  final int? id;
  final int sesiId;
  final int timestamp; // Unix timestamp
  final int spo2; // SpO2 percentage
  final int status; // 0 = no snore, 1 = snore

  SensorReading({
    this.id,
    required this.sesiId,
    required this.timestamp,
    required this.spo2,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'sesi_id': sesiId,
      'timestamp': timestamp,
      'spo2': spo2,
      'status': status,
    };
  }

  factory SensorReading.fromMap(Map<String, dynamic> map) {
    return SensorReading(
      id: map['id'],
      sesiId: map['sesi_id'],
      timestamp: map['timestamp'],
      spo2: map['spo2'],
      status: map['status'],
    );
  }

  // Create from ESP32C3 JSON data
  factory SensorReading.fromEsp32c3Json(Map<String, dynamic> json, int sesiId) {
    return SensorReading(
      sesiId: sesiId,
      timestamp: json['timestamp'] as int,
      spo2: (double.parse(json['spo2'].toString())).round(),
      status: json['status'] as int,
    );
  }
}