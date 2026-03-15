import 'dart:convert';

class Urun {
  final String id;
  final String isletmeId;
  final String? urunKodu;
  final String urunAdi;
  final String? isim2;
  final String? birim;
  final String? kategori;
  final List<String> barkodlar;
  final bool aktif;

  Urun({
    required this.id,
    required this.isletmeId,
    this.urunKodu,
    required this.urunAdi,
    this.isim2,
    this.birim,
    this.kategori,
    this.barkodlar = const [],
    this.aktif = true,
  });

  factory Urun.fromJson(Map<String, dynamic> json) {
    List<String> parseBarkodlar(dynamic val) {
      if (val is List) return val.map((e) => e.toString()).toList();
      if (val is String && val.isNotEmpty) {
        try {
          final decoded = val.startsWith('[')
              ? (jsonDecode(val) as List).map((e) => e.toString()).toList()
              : val.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          return decoded;
        } catch (_) {
          return [val];
        }
      }
      return [];
    }

    return Urun(
      id: json['id']?.toString() ?? '',
      isletmeId: (json['isletme_id'] ?? json['isletmeId'])?.toString() ?? '',
      urunKodu: json['urun_kodu'],
      urunAdi: json['urun_adi'] ?? '',
      isim2: json['isim_2'],
      birim: json['birim'],
      kategori: json['kategori'],
      barkodlar: parseBarkodlar(json['barkodlar']),
      aktif: json['aktif'] == true || json['aktif'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'isletme_id': isletmeId,
    'urun_kodu': urunKodu,
    'urun_adi': urunAdi,
    'isim_2': isim2,
    'birim': birim,
    'kategori': kategori,
    'barkodlar': barkodlar,
    'aktif': aktif,
  };
}
