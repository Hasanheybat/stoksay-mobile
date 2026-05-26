import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/sayim_service.dart';
import '../services/socket_service.dart';
import '../services/webrtc_service.dart';
import 'app_layout.dart';

const _P = Color(0xFF6C53F5);

class DenetlemeDetayScreen extends ConsumerStatefulWidget {
  final String sayimId;
  final Map<String, dynamic>? meta;
  const DenetlemeDetayScreen({super.key, required this.sayimId, this.meta});

  @override
  ConsumerState<DenetlemeDetayScreen> createState() => _DenetlemeDetayScreenState();
}

class _DenetlemeDetayScreenState extends ConsumerState<DenetlemeDetayScreen> {
  List<Map<String, dynamic>> _kalemler = [];
  bool _yukleniyor = true;
  bool _baslatildi = false;
  int _kalanSn = 0;
  Timer? _kalanTimer;
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  WebRtcService? _rtc;
  RTCVideoRenderer? _renderer;
  bool _kameraAcik = false;
  String? _sayimYapanId;

  @override
  void initState() {
    super.initState();
    _sayimYapanId = widget.meta?['kullanici_id']?.toString();
    SocketService.connect();
    SocketService.emit('sayim:join', {'sayim_id': widget.sayimId});
    _socketSub = SocketService.events.listen(_handleSocketEvent);
    _yukleKalemler();
    _baslat();
  }

  Future<void> _yukleKalemler() async {
    try {
      final list = await SayimService.kalemListele(widget.sayimId);
      if (!mounted) return;
      setState(() {
        _kalemler = list.reversed.toList();
        _yukleniyor = false;
      });
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _baslat() {
    SocketService.emitWithAck('denetleme:baslat', {'sayim_id': widget.sayimId}, (resp) {
      if (resp is Map && resp['ok'] == true) {
        if (!mounted) return;
        setState(() {
          _baslatildi = true;
          _kalanSn = (resp['limit_sn'] as num?)?.toInt() ?? 120;
        });
        _kalanTimer?.cancel();
        _kalanTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) { t.cancel(); return; }
          setState(() => _kalanSn--);
          if (_kalanSn <= 0) {
            t.cancel();
            _bitir(sebep: 'limit');
          }
        });
      } else {
        final hata = (resp is Map ? resp['hata'] : null) ?? 'Baslatilamadi';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(hata.toString())),
          );
        }
      }
    });
  }

  Future<void> _bitir({String sebep = 'manuel'}) async {
    SocketService.emit('denetleme:sonlandir', {'sayim_id': widget.sayimId});
    _kalanTimer?.cancel();
    await _rtc?.dispose();
    await _renderer?.dispose();
    if (mounted) {
      setState(() {
        _baslatildi = false;
        _kameraAcik = false;
        _renderer = null;
      });
    }
  }

  Future<void> _kameraAc() async {
    if (_sayimYapanId == null) return;
    _rtc = WebRtcService();
    _renderer = RTCVideoRenderer();
    await _renderer!.initialize();
    _rtc!.onRemoteStream = (stream) {
      if (!mounted) return;
      setState(() {
        _renderer!.srcObject = stream;
        _kameraAcik = true;
      });
    };
    _rtc!.onClose = () {
      if (mounted) setState(() => _kameraAcik = false);
    };
    await _rtc!.hazirla(kameraAc: false);
    await _rtc!.startCall(targetUserId: _sayimYapanId!);
  }

  Future<void> _handleSocketEvent(Map<String, dynamic> ev) async {
    final type = ev['type'];
    final data = ev['data'];
    if (type == 'sayim:kalem_eklendi' && data is Map) {
      final kalem = Map<String, dynamic>.from(data['kalem'] ?? {});
      if (!mounted) return;
      setState(() {
        _kalemler = [kalem, ..._kalemler];
      });
    } else if (type == 'sayim:kalem_silindi' && data is Map) {
      final id = data['kalem_id'];
      if (!mounted) return;
      setState(() {
        _kalemler.removeWhere((k) => k['id'].toString() == id.toString());
      });
    } else if (type == 'denetleme:bitti') {
      await _bitir(sebep: 'sunucu');
    } else if (type == 'webrtc:answer' && data is Map) {
      await _rtc?.handleAnswer(Map<String, dynamic>.from(data['sdp']));
    } else if (type == 'webrtc:ice' && data is Map) {
      await _rtc?.handleIce(Map<String, dynamic>.from(data['candidate']));
    }
  }

  @override
  void dispose() {
    _kalanTimer?.cancel();
    _socketSub?.cancel();
    SocketService.emit('sayim:leave', {'sayim_id': widget.sayimId});
    SocketService.emit('denetleme:sonlandir', {'sayim_id': widget.sayimId});
    _rtc?.dispose();
    _renderer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.meta?['ad']?.toString() ?? 'Sayım';
    final kullaniciAd = widget.meta?['kullanici_ad']?.toString() ?? '—';
    return AppLayout(
      pageTitle: 'Denetle: $ad',
      showBack: true,
      child: Column(
        children: [
          // Üst banner — durum + kalan süre + buton
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            color: _baslatildi ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
            child: Row(
              children: [
                Icon(_baslatildi ? Icons.fiber_manual_record : Icons.pause_circle,
                    color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _baslatildi ? '$kullaniciAd · canlı izleniyor' : 'Bağlanıyor...',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_baslatildi)
                  Text('${_kalanSn}sn',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          // Kamera buton + canlı video
          if (_baslatildi)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: !_kameraAcik
                  ? GestureDetector(
                      onTap: _kameraAc,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: _P,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Kameraya Bak',
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 200,
                        color: Colors.black,
                        child: _renderer == null
                            ? const Center(child: CircularProgressIndicator(color: Colors.white))
                            : RTCVideoView(_renderer!,
                                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                      ),
                    ),
            ),
          // Kalem listesi (canlı)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                const Icon(Icons.list_alt, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Text('${_kalemler.length} kalem',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
              ],
            ),
          ),
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator(color: _P, strokeWidth: 2))
                : _kalemler.isEmpty
                    ? const Center(child: Text('Henüz kalem yok', style: TextStyle(color: Color(0xFF9CA3AF))))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: _kalemler.length,
                        itemBuilder: (ctx, i) {
                          final k = _kalemler[i];
                          final urun = k['isletme_urunler'] as Map<String, dynamic>? ?? {};
                          final ad = urun['urun_adi']?.toString() ?? '—';
                          final miktar = k['miktar']?.toString() ?? '0';
                          final birim = k['birim']?.toString() ?? '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(ad,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                                Text('$miktar $birim',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _P)),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
