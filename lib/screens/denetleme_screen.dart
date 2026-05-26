import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/denetleme_service.dart';
import 'app_layout.dart';

const _P = Color(0xFF6C53F5);

class DenetlemeScreen extends ConsumerStatefulWidget {
  const DenetlemeScreen({super.key});

  @override
  ConsumerState<DenetlemeScreen> createState() => _DenetlemeScreenState();
}

class _DenetlemeScreenState extends ConsumerState<DenetlemeScreen> {
  List<Map<String, dynamic>> _sayimlar = [];
  bool _yukleniyor = true;
  String _arama = '';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _yukle();
    // Her 5 sn'de bir liste yenile
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _yukle(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _yukle({bool silent = false}) async {
    if (!silent) setState(() => _yukleniyor = true);
    try {
      final data = await DenetlemeService.aktifSayimlar();
      if (!mounted) return;
      setState(() {
        _sayimlar = data;
        _yukleniyor = false;
      });
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  List<Map<String, dynamic>> get _filtreli {
    if (_arama.isEmpty) return _sayimlar;
    final q = _arama.toLowerCase();
    return _sayimlar.where((s) {
      final ad = (s['ad'] ?? '').toString().toLowerCase();
      final kad = (s['kullanici_ad'] ?? '').toString().toLowerCase();
      final isl = (s['isletme_ad'] ?? '').toString().toLowerCase();
      return ad.contains(q) || kad.contains(q) || isl.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      pageTitle: 'Denetleme',
      showBack: true,
      child: Column(
        children: [
          // Arama
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              onChanged: (v) => setState(() => _arama = v),
              decoration: InputDecoration(
                hintText: 'Kullanıcı / işletme / sayım ara...',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
            ),
          ),
          // Liste
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator(color: _P, strokeWidth: 2.5))
                : _filtreli.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility_off, size: 48, color: Color(0xFFD1D5DB)),
                            SizedBox(height: 8),
                            Text('Aktif sayım yok', style: TextStyle(color: Color(0xFF9CA3AF))),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _yukle(),
                        color: _P,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                          itemCount: _filtreli.length,
                          itemBuilder: (ctx, i) {
                            final s = _filtreli[i];
                            return _SayimKarti(
                              sayim: s,
                              onTap: () {
                                context.push('/denetleme/${s['id']}', extra: s);
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _SayimKarti extends StatelessWidget {
  final Map<String, dynamic> sayim;
  final VoidCallback onTap;
  const _SayimKarti({required this.sayim, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ad = sayim['ad']?.toString() ?? '—';
    final kullanici = sayim['kullanici_ad']?.toString() ?? '—';
    final isletme = sayim['isletme_ad']?.toString() ?? '—';
    final depo = sayim['depo_ad']?.toString() ?? '';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ad, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                  const SizedBox(height: 2),
                  Text('$kullanici · $isletme${depo.isNotEmpty ? " · $depo" : ""}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 18),
          ],
        ),
      ),
    );
  }
}
