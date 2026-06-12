import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_service.dart';
import 'api_service.dart';

/// WebRTC peer connection helper — sayim_yapan + denetleyici tarafi.
class WebRtcService {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  String? _peerUserId;

  // ICE aday yarışı düzeltmesi: remote description set edilmeden gelen
  // adaylar eklenemez (addCandidate hata verir ve aday KAYBOLUR).
  // Bekletip remote description sonrası flush ediyoruz.
  final List<RTCIceCandidate> _bekleyenAdaylar = [];
  bool _remoteDescHazir = false;

  // Yeniden gonderim icin son offer/answer SDP'leri saklanir:
  // - Denetleyici: answer gelmezse ayni offer'i tekrar gonderir (reofferGonder)
  // - Sayim yapan: ayni peer'dan cift offer gelirse answer'i tekrar gonderir
  //   (answer paketi kaybolduysa baglanti yine kurulur)
  Map<String, dynamic>? _sonOfferSdp;
  Map<String, dynamic>? _sonAnswerSdp;

  /// Remote description set edildi mi? (answer/offer islendi)
  bool get remoteDescHazir => _remoteDescHazir;

  void Function(MediaStream stream)? onRemoteStream;
  void Function()? onClose;
  void Function(String durum)? onDurum; // teshis: baglanti/ICE durumu

  static Future<Map<String, dynamic>> _fetchIceServers() async {
    try {
      final res = await ApiService.dio.get('/denetleme/ice-servers');
      final servers = res.data['iceServers'] ?? [];
      return {'iceServers': List<Map<String, dynamic>>.from(servers)};
    } catch (_) {
      return {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
      };
    }
  }

  /// SAYIM_YAPAN tarafi: kameray? acar, gelen offer'a answer gonderir
  Future<void> hazirla({required bool kameraAc}) async {
    final ice = await _fetchIceServers();
    _pc = await createPeerConnection(ice);

    if (kameraAc) {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'video': {'facingMode': 'environment'}, // arka kamera tercih
        'audio': false,
      });
      for (final track in _localStream!.getTracks()) {
        await _pc!.addTrack(track, _localStream!);
      }
    }

    _pc!.onIceCandidate = (cand) {
      if (_peerUserId == null) return;
      SocketService.emit('webrtc:ice', {
        'target_user_id': _peerUserId,
        'candidate': cand.toMap(),
      });
    };

    _pc!.onTrack = (event) {
      if (kDebugMode) debugPrint('[webrtc] onTrack: ${event.track.kind}');
      onDurum?.call('Görüntü geldi');
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        onRemoteStream?.call(_remoteStream!);
      }
    };

    _pc!.onIceGatheringState = (s) {
      if (kDebugMode) debugPrint('[webrtc] iceGathering: $s');
    };

    _pc!.onIceConnectionState = (s) {
      if (kDebugMode) debugPrint('[webrtc] iceConn: $s');
      final t = s.toString().replaceFirst('RTCIceConnectionState', '');
      onDurum?.call('ICE: $t');
    };

    _pc!.onConnectionState = (state) {
      if (kDebugMode) debugPrint('[webrtc] state: $state');
      final t = state.toString().replaceFirst('RTCPeerConnectionState', '');
      onDurum?.call('Bağlantı: $t');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        onClose?.call();
      }
    };
  }

  /// DENETLEYICI tarafi: peer'a offer baslatir
  Future<void> startCall({required String targetUserId}) async {
    _peerUserId = targetUserId;
    // Denetleyici sadece izler (kendi track'i yok). createOffer'in bos
    // SDP uretmemesi icin recvonly video m-line ekle — yoksa sayim_yapan
    // tarafi kamerayi geri gonderemez ve goruntu hic gelmez.
    if (_localStream == null) {
      await _pc!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
    }
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    _sonOfferSdp = {'type': offer.type, 'sdp': offer.sdp};
    onDurum?.call('İstek gönderildi, yanıt bekleniyor...');
    SocketService.emit('webrtc:offer', {
      'target_user_id': targetUserId,
      'sdp': _sonOfferSdp,
    });
  }

  /// DENETLEYICI tarafi: answer gelmediyse ayni offer'i tekrar gonderir.
  /// (Karsi taraf hazirlik sirasindaysa veya paket kaybolduysa kurtarir.)
  void reofferGonder() {
    if (_peerUserId == null || _sonOfferSdp == null || _remoteDescHazir) return;
    SocketService.emit('webrtc:offer', {
      'target_user_id': _peerUserId,
      'sdp': _sonOfferSdp,
    });
  }

  /// Hazirlik tamam mi? (hazirla() bitti, peer connection kuruldu)
  bool get hazir => _pc != null;

  /// SAYIM_YAPAN tarafi: gelen offer'i kabul edip answer gonderir
  Future<void> acceptOffer({required String fromUserId, required Map<String, dynamic> sdp}) async {
    if (_pc == null) return; // hazirlik tamamlanmadan offer islenemez

    // Ayni peer'dan tekrar offer (retry) — answer kaybolmus olabilir,
    // mevcut baglantiyi bozmadan sakli answer'i tekrar gonder
    if (_remoteDescHazir && fromUserId == _peerUserId && _sonAnswerSdp != null) {
      SocketService.emit('webrtc:answer', {
        'target_user_id': fromUserId,
        'sdp': _sonAnswerSdp,
      });
      return;
    }

    _peerUserId = fromUserId;
    await _pc!.setRemoteDescription(RTCSessionDescription(sdp['sdp'], sdp['type']));
    await _adaylariFlushEt();
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    _sonAnswerSdp = {'type': answer.type, 'sdp': answer.sdp};
    SocketService.emit('webrtc:answer', {
      'target_user_id': fromUserId,
      'sdp': _sonAnswerSdp,
    });
  }

  /// DENETLEYICI tarafi: gelen answer'i isle
  Future<void> handleAnswer(Map<String, dynamic> sdp) async {
    if (_pc == null) return;
    await _pc!.setRemoteDescription(RTCSessionDescription(sdp['sdp'], sdp['type']));
    await _adaylariFlushEt();
  }

  Future<void> handleIce(Map<String, dynamic> candidate) async {
    final aday = RTCIceCandidate(
      candidate['candidate'],
      candidate['sdpMid'],
      candidate['sdpMLineIndex'],
    );
    // Remote description henuz yoksa beklet — yoksa aday kaybolur
    if (_pc == null || !_remoteDescHazir) {
      _bekleyenAdaylar.add(aday);
      return;
    }
    try {
      await _pc!.addCandidate(aday);
    } catch (e) {
      if (kDebugMode) debugPrint('[webrtc] addCandidate hatasi: $e');
    }
  }

  Future<void> _adaylariFlushEt() async {
    _remoteDescHazir = true;
    final bekleyenler = List<RTCIceCandidate>.from(_bekleyenAdaylar);
    _bekleyenAdaylar.clear();
    for (final aday in bekleyenler) {
      try {
        await _pc!.addCandidate(aday);
      } catch (e) {
        if (kDebugMode) debugPrint('[webrtc] flush addCandidate hatasi: $e');
      }
    }
  }

  Future<void> dispose() async {
    try {
      await _localStream?.dispose();
    } catch (_) {}
    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;
    _localStream = null;
    _remoteStream = null;
    _peerUserId = null;
    _bekleyenAdaylar.clear();
    _remoteDescHazir = false;
    _sonOfferSdp = null;
    _sonAnswerSdp = null;
  }

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  String? get peerUserId => _peerUserId;
}
