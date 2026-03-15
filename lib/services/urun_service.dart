import 'api_service.dart';

class UrunService {
  static Future<List<Map<String, dynamic>>> listele(String isletmeId, {int sayfa = 1, int limit = 50, String? arama, String? alan}) async {
    final res = await ApiService.dio.get('/urunler', queryParameters: {
      'isletme_id': isletmeId,
      'sayfa': sayfa,
      'limit': limit,
      if (arama != null && arama.isNotEmpty) 'q': arama,
      if (alan != null && alan.isNotEmpty) 'alan': alan,
    });
    final raw = res.data;
    if (raw is Map && raw['data'] is List) {
      return List<Map<String, dynamic>>.from(raw['data']);
    }
    if (raw is List) return List<Map<String, dynamic>>.from(raw);
    return [];
  }

  static Future<Map<String, dynamic>?> barkodBul(String isletmeId, String barkod) async {
    final res = await ApiService.dio.get('/urunler/barkod/$barkod', queryParameters: {'isletme_id': isletmeId});
    return Map<String, dynamic>.from(res.data);
  }

  static Future<Map<String, dynamic>> ekle(Map<String, dynamic> data) async {
    final res = await ApiService.dio.post('/urunler', data: data);
    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data);
    }
    return {};
  }

  static Future<Map<String, dynamic>> guncelle(String id, Map<String, dynamic> data) async {
    final res = await ApiService.dio.put('/urunler/$id', data: data);
    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data);
    }
    return {};
  }

  static Future<void> sil(String id) async {
    await ApiService.dio.delete('/urunler/$id');
  }
}
