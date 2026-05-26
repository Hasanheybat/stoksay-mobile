class Kullanici {
  final String id;
  final String adSoyad;
  final String email;
  final String rol;
  final bool aktif;
  final Map<String, dynamic> ayarlar;
  final bool denetleyiciYetkisi;
  final bool sadeceDenetleyici;
  final int? izlemeLimitSaniye;

  Kullanici({
    required this.id,
    required this.adSoyad,
    required this.email,
    required this.rol,
    this.aktif = true,
    this.ayarlar = const {},
    this.denetleyiciYetkisi = false,
    this.sadeceDenetleyici = false,
    this.izlemeLimitSaniye,
  });

  bool get birimOtomatik => ayarlar['birim_otomatik'] == true;
  bool get barkodSesi => ayarlar['barkod_sesi'] != false;

  factory Kullanici.fromJson(Map<String, dynamic> json) {
    return Kullanici(
      id: json['id']?.toString() ?? '',
      adSoyad: json['ad_soyad'] ?? json['adSoyad'] ?? '',
      email: json['email'] ?? '',
      rol: json['rol'] ?? 'kullanici',
      aktif: json['aktif'] == true || json['aktif'] == 1,
      ayarlar: json['ayarlar'] is Map ? Map<String, dynamic>.from(json['ayarlar']) : {},
      denetleyiciYetkisi: json['denetleyici_yetkisi'] == true || json['denetleyici_yetkisi'] == 1,
      sadeceDenetleyici: json['sadece_denetleyici'] == true || json['sadece_denetleyici'] == 1,
      izlemeLimitSaniye: json['izleme_limit_saniye'] == null ? null : int.tryParse(json['izleme_limit_saniye'].toString()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'ad_soyad': adSoyad,
    'email': email,
    'rol': rol,
    'aktif': aktif,
    'ayarlar': ayarlar,
    'denetleyici_yetkisi': denetleyiciYetkisi,
    'sadece_denetleyici': sadeceDenetleyici,
    'izleme_limit_saniye': izlemeLimitSaniye,
  };
}
