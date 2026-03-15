import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class StorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static bool get hasToken => _prefs?.getString(ApiConfig.tokenKey) != null;
  static String? get token => _prefs?.getString(ApiConfig.tokenKey);

  static Future<void> saveToken(String token) async {
    await _prefs?.setString(ApiConfig.tokenKey, token);
  }

  static Future<void> removeToken() async {
    await _prefs?.remove(ApiConfig.tokenKey);
  }
}
