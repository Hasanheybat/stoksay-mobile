import 'package:shared_preferences/shared_preferences.dart';

/// Offline modda oluşturulan kayıtlar için negatif temp ID üretir.
/// Online ID'ler UUID string, offline ID'ler "temp_-1", "temp_-2" gibi string.
/// Böylece çakışma olmaz.
class OfflineIdService {
  static const _key = 'offline_temp_id_counter';

  /// Bir sonraki temp ID'yi string olarak üretir ("temp_-1", "temp_-2", ...)
  static Future<String> nextId() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_key) ?? 0;
    final next = current - 1;
    await prefs.setInt(_key, next);
    return 'temp_$next';
  }

  /// Verilen ID'nin offline temp ID olup olmadığını kontrol eder
  static bool isTempId(dynamic id) {
    if (id is String) return id.startsWith('temp_');
    return false;
  }

  /// Sayacı sıfırla (tüm offline veriler sync edildikten sonra)
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
