class Transaksi {
  final int? id;
  final int sesiId;
  final String waktuMulai;
  final String? waktuSelesai;
  final int? durasi; // in minutes

  Transaksi({
    this.id,
    required this.sesiId,
    required this.waktuMulai,
    this.waktuSelesai,
    this.durasi,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'sesi_id': sesiId,
      'waktu_mulai': waktuMulai,
      'waktu_selesai': waktuSelesai,
      'durasi': durasi,
    };
  }

  factory Transaksi.fromMap(Map<String, dynamic> map) {
    return Transaksi(
      id: map['id'],
      sesiId: map['sesi_id'],
      waktuMulai: map['waktu_mulai'],
      waktuSelesai: map['waktu_selesai'],
      durasi: map['durasi'],
    );
  }

  Transaksi copyWith({
    int? id,
    int? sesiId,
    String? waktuMulai,
    String? waktuSelesai,
    int? durasi,
  }) {
    return Transaksi(
      id: id ?? this.id,
      sesiId: sesiId ?? this.sesiId,
      waktuMulai: waktuMulai ?? this.waktuMulai,
      waktuSelesai: waktuSelesai ?? this.waktuSelesai,
      durasi: durasi ?? this.durasi,
    );
  }
}