import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'storage_service.dart';
import 'api_service.dart';

/// Tek socket baglantisi — uygulama omru boyunca acik.
class SocketService {
  static io.Socket? _socket;
  static String? _currentToken;

  /// Tum stream'ler — global event bus (sayim ekranlari + denetleme ekranlari dinler)
  static final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get events => _events.stream;

  /// Baglanti kur (token degistiyse yeniden olustur)
  static Future<void> connect() async {
    final token = StorageService.token;
    if (token == null || token.isEmpty) return;

    if (_socket != null && _currentToken == token && _socket!.connected) {
      return; // Zaten bagli, ayni token
    }

    // Eski baglanti varsa kapat
    if (_socket != null) {
      _socket!.dispose();
      _socket = null;
    }

    _currentToken = token;
    final base = ApiService.dio.options.baseUrl;
    // baseURL ornek: https://inventory.minupos.com/api -> socket: https://inventory.minupos.com
    final origin = Uri.parse(base).replace(path: '').toString();

    _socket = io.io(
      origin,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .setReconnectionAttempts(99)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      if (kDebugMode) debugPrint('[socket] connected');
      _events.add({'type': '_connect'});
    });
    _socket!.onDisconnect((_) {
      if (kDebugMode) debugPrint('[socket] disconnected');
      _events.add({'type': '_disconnect'});
    });
    _socket!.onConnectError((err) {
      if (kDebugMode) debugPrint('[socket] connect error: $err');
    });

    // Tum eventleri stream'e basla
    for (final ev in _allEvents) {
      _socket!.on(ev, (data) {
        _events.add({'type': ev, 'data': data});
      });
    }

    _socket!.connect();
  }

  static const _allEvents = [
    'sayim:joined',
    'sayim:kalem_eklendi',
    'sayim:kalem_silindi',
    'sayim:kalem_guncellendi',
    'denetleme:basladi',
    'denetleme:bitti',
    'webrtc:offer',
    'webrtc:answer',
    'webrtc:ice',
    // Yetki/kullanici degisikligi — web'den rol/isletme atandiginda backend emit eder
    'kullanici:yetki_guncellendi',
    'kullanici:pasif',
    'kullanici:isletme_atandi',
    'kullanici:isletme_kaldirildi',
  ];

  static void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  /// emit + ack callback
  static void emitWithAck(String event, dynamic data, void Function(dynamic) ack) {
    _socket?.emitWithAck(event, data, ack: ack);
  }

  static bool get connected => _socket?.connected ?? false;

  static Future<void> disconnect() async {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _currentToken = null;
  }
}
