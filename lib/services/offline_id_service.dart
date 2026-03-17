import 'dart:math';

/// Offline modda oluşturulan kayıtlar için rastgele temp ID üretir.
/// Online ID'ler UUID string, offline ID'ler "temp_" prefix'li rastgele string.
/// Böylece çakışma olmaz ve tahmin edilemez.
class OfflineIdService {
  static final _random = Random.secure();

  /// Rastgele temp ID üretir ("temp_1710678234567_8392" gibi)
  static Future<String> nextId() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = _random.nextInt(9999);
    return 'temp_${ts}_$rand';
  }

  /// Verilen ID'nin offline temp ID olup olmadığını kontrol eder
  static bool isTempId(dynamic id) {
    if (id is String) return id.startsWith('temp_');
    return false;
  }
}
