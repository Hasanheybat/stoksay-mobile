import 'api_service.dart';

class DepoService {
  static Future<List<Map<String, dynamic>>> listele(String isletmeId) async {
    final res = await ApiService.dio.get('/depolar', queryParameters: {'isletme_id': isletmeId, 'sayfa': 1, 'limit': 500});
    // API returns {data: [...]} or plain list
    final raw = res.data;
    if (raw is Map && raw['data'] is List) {
      return List<Map<String, dynamic>>.from(raw['data']);
    }
    if (raw is List) return List<Map<String, dynamic>>.from(raw);
    return [];
  }

  static Future<Map<String, dynamic>> ekle(String isletmeId, String ad, {String? konum}) async {
    final data = <String, dynamic>{
      'isletme_id': isletmeId,
      'ad': ad,
    };
    if (konum != null) data['konum'] = konum;
    final res = await ApiService.dio.post('/depolar', data: data);
    return Map<String, dynamic>.from(res.data);
  }

  static Future<Map<String, dynamic>> guncelle(String id, Map<String, dynamic> data) async {
    final res = await ApiService.dio.put('/depolar/$id', data: data);
    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data);
    }
    return {};
  }

  static Future<void> sil(String id) async {
    await ApiService.dio.delete('/depolar/$id');
  }
}
