class Sesi {
  final int? id;
  final String nama;
  final String tanggal;
  final String waktuMulai;
  final String? waktuSelesai;
  final int? durasi; // in minutes
  final String? deviceId;
  final String? catatan;

  Sesi({
    this.id,
    required this.nama,
    required this.tanggal,
    required this.waktuMulai,
    this.waktuSelesai,
    this.durasi,
    this.deviceId,
    this.catatan,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nama': nama,
      'tanggal': tanggal,
      'waktu_mulai': waktuMulai,
      'waktu_selesai': waktuSelesai,
      'durasi': durasi,
      'device_id': deviceId,
      'catatan': catatan,
    };
  }

  factory Sesi.fromMap(Map<String, dynamic> map) {
    return Sesi(
      id: map['id'],
      nama: map['nama'],
      tanggal: map['tanggal'],
      waktuMulai: map['waktu_mulai'],
      waktuSelesai: map['waktu_selesai'],
      durasi: map['durasi'],
      deviceId: map['device_id'],
      catatan: map['catatan'],
    );
  }

  Sesi copyWith({
    int? id,
    String? nama,
    String? tanggal,
    String? waktuMulai,
    String? waktuSelesai,
    int? durasi,
    String? deviceId,
    String? catatan,
  }) {
    return Sesi(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      tanggal: tanggal ?? this.tanggal,
      waktuMulai: waktuMulai ?? this.waktuMulai,
      waktuSelesai: waktuSelesai ?? this.waktuSelesai,
      durasi: durasi ?? this.durasi,
      deviceId: deviceId ?? this.deviceId,
      catatan: catatan ?? this.catatan,
    );
  }
}