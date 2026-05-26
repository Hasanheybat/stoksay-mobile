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

  void Function(MediaStream stream)? onRemoteStream;
  void Function()? onClose;

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
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        onRemoteStream?.call(_remoteStream!);
      }
    };

    _pc!.onConnectionState = (state) {
      if (kDebugMode) debugPrint('[webrtc] state: $state');
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
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    SocketService.emit('webrtc:offer', {
      'target_user_id': targetUserId,
      'sdp': {'type': offer.type, 'sdp': offer.sdp},
    });
  }

  /// SAYIM_YAPAN tarafi: gelen offer'i kabul edip answer gonderir
  Future<void> acceptOffer({required String fromUserId, required Map<String, dynamic> sdp}) async {
    _peerUserId = fromUserId;
    await _pc!.setRemoteDescription(RTCSessionDescription(sdp['sdp'], sdp['type']));
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    SocketService.emit('webrtc:answer', {
      'target_user_id': fromUserId,
      'sdp': {'type': answer.type, 'sdp': answer.sdp},
    });
  }

  /// DENETLEYICI tarafi: gelen answer'i isle
  Future<void> handleAnswer(Map<String, dynamic> sdp) async {
    if (_pc == null) return;
    await _pc!.setRemoteDescription(RTCSessionDescription(sdp['sdp'], sdp['type']));
  }

  Future<void> handleIce(Map<String, dynamic> candidate) async {
    if (_pc == null) return;
    await _pc!.addCandidate(RTCIceCandidate(
      candidate['candidate'],
      candidate['sdpMid'],
      candidate['sdpMLineIndex'],
    ));
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
  }

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  String? get peerUserId => _peerUserId;
}
