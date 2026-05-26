import 'api_service.dart';

class DenetlemeService {
  static Future<Map<String, dynamic>> durum() async {
    final res = await ApiService.dio.get('/denetleme/durum');
    return Map<String, dynamic>.from(res.data);
  }

  static Future<List<Map<String, dynamic>>> aktifSayimlar() async {
    final res = await ApiService.dio.get('/denetleme/aktif-sayimlar');
    final list = res.data['data'] ?? [];
    return List<Map<String, dynamic>>.from(list);
  }

  static Future<List<Map<String, dynamic>>> aktifIzlemeler() async {
    final res = await ApiService.dio.get('/denetleme/aktif-izlemeler');
    final list = res.data['data'] ?? [];
    return List<Map<String, dynamic>>.from(list);
  }
}
