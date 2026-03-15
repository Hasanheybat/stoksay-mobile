import 'api_service.dart';

class ProfilService {
  static Future<Map<String, dynamic>> stats(String isletmeId) async {
    final res = await ApiService.dio.get('/profil/stats', queryParameters: {'isletme_id': isletmeId});
    return Map<String, dynamic>.from(res.data);
  }

  static Future<void> ayarlarGuncelle(Map<String, dynamic> ayarlar) async {
    await ApiService.dio.put('/profil/ayarlar', data: ayarlar);
  }
}
