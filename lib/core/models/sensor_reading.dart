class SensorReading {
  final int? id;
  final int sesiId;
  final int timestamp; // Unix timestamp
  final double spo2; // SpO2 percentage
  final int status; // 0 = no snore, 1 = snore
  final int? stabilizing; // 0 = not stabilizing, 1 = stabilizing

  SensorReading({
    this.id,
    required this.sesiId,
    required this.timestamp,
    required this.spo2,
    required this.status,
    this.stabilizing,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'sesi_id': sesiId,
      'timestamp': timestamp,
      'spo2': spo2,
      'status': status,
      if (stabilizing != null) 'stabilizing': stabilizing,
    };
  }
  factory SensorReading.fromMap(Map<String, dynamic> map) {
    return SensorReading(
      id: map['id'],
      sesiId: map['sesi_id'],
      timestamp: map['timestamp'],
      spo2: (map['spo2'] as num).toDouble(),
      status: map['status'],
      stabilizing: map['stabilizing'],
    );
  }
  // Create from ESP32C3 JSON data
  factory SensorReading.fromEsp32c3Json(Map<String, dynamic> json, int sesiId) {
    return SensorReading(
      sesiId: sesiId,
      timestamp: json['timestamp'] as int,
      spo2: double.parse(json['spo2'].toString()),
      status: json['status'] as int,
      stabilizing: json['stabilizing'] as int?,
    );
  }
}