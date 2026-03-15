import 'api_service.dart';

class SayimService {
  static Future<List<Map<String, dynamic>>> listele(String isletmeId) async {
    final res = await ApiService.dio.get('/sayimlar', queryParameters: {'isletme_id': isletmeId, 'limit': 500, 'toplama': '0'});
    // API returns {data: [...]} or plain list
    final raw = res.data;
    if (raw is Map && raw['data'] is List) {
      return List<Map<String, dynamic>>.from(raw['data']);
    }
    if (raw is List) return List<Map<String, dynamic>>.from(raw);
    return [];
  }

  static Future<Map<String, dynamic>> detay(String sayimId) async {
    final res = await ApiService.dio.get('/sayimlar/$sayimId');
    return Map<String, dynamic>.from(res.data);
  }

  static Future<Map<String, dynamic>> olustur(Map<String, dynamic> data) async {
    final res = await ApiService.dio.post('/sayimlar', data: data);
    return Map<String, dynamic>.from(res.data);
  }

  static Future<Map<String, dynamic>> guncelle(String id, Map<String, dynamic> data) async {
    final res = await ApiService.dio.put('/sayimlar/$id', data: data);
    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data);
    }
    return {};
  }

  static Future<void> sil(String id) async {
    await ApiService.dio.delete('/sayimlar/$id');
  }

  static Future<void> tamamla(dynamic id) async {
    await ApiService.dio.put('/sayimlar/$id/tamamla');
  }

  static Future<List<Map<String, dynamic>>> kalemListele(String sayimId) async {
    final res = await ApiService.dio.get('/sayimlar/$sayimId/kalemler');
    final raw = res.data;
    if (raw is List) return List<Map<String, dynamic>>.from(raw);
    if (raw is Map && raw['data'] is List) {
      return List<Map<String, dynamic>>.from(raw['data']);
    }
    return [];
  }

  static Future<Map<String, dynamic>> kalemEkle(String sayimId, Map<String, dynamic> data) async {
    final res = await ApiService.dio.post('/sayimlar/$sayimId/kalem', data: data);
    return Map<String, dynamic>.from(res.data);
  }

  static Future<void> kalemGuncelle(String sayimId, dynamic kalemId, Map<String, dynamic> data) async {
    await ApiService.dio.put('/sayimlar/$sayimId/kalem/$kalemId', data: data);
  }

  static Future<void> kalemSil(String sayimId, dynamic kalemId) async {
    await ApiService.dio.delete('/sayimlar/$sayimId/kalem/$kalemId');
  }

  static Future<Map<String, dynamic>> topla({
    required List<String> sayimIds,
    required String ad,
    required String isletmeId,
  }) async {
    final res = await ApiService.dio.post('/sayimlar/topla', data: {
      'sayim_ids': sayimIds,
      'ad': ad,
      'isletme_id': isletmeId,
    });
    if (res.data is Map) return Map<String, dynamic>.from(res.data);
    return {};
  }

  static Future<List<Map<String, dynamic>>> toplanmisListele(String isletmeId) async {
    final res = await ApiService.dio.get('/sayimlar', queryParameters: {
      'isletme_id': isletmeId,
      'toplama': '1',
      'limit': 500,
    });
    final raw = res.data;
    if (raw is Map && raw['data'] is List) {
      return List<Map<String, dynamic>>.from(
        (raw['data'] as List).where((s) => s['durum'] != 'silindi'),
      );
    }
    if (raw is List) {
      return List<Map<String, dynamic>>.from(
        raw.where((s) => s['durum'] != 'silindi'),
      );
    }
    return [];
  }
}
