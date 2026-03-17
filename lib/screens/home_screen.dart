import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/isletme_provider.dart';
import '../providers/connectivity_provider.dart';
import '../widgets/sync_result_dialog.dart';
import '../widgets/bildirim.dart';
import 'app_layout.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _syncing = false;
  bool _syncDone = false;
  String _syncStats = '';

  Future<void> _syncData() async {
    if (_syncing) return;
    final connectivity = ref.read(connectivityProvider);

    if (connectivity.offlineMode) {
      // Offline moddayken verileri güncelle devre dışı
      return;
    }

    setState(() {
      _syncing = true;
      _syncDone = false;
      _syncStats = '';
    });

    try {
      await ref.read(authProvider.notifier).oturumKontrol();
      await ref.read(isletmeProvider.notifier).yukle();
      final isletme = ref.read(isletmeProvider);
      setState(() {
        _syncing = false;
        _syncDone = true;
        _syncStats = '${isletme.isletmeler.length} işletme senkronize edildi';
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _syncDone = false);
      });
    } catch (_) {
      setState(() {
        _syncing = false;
        _syncStats = 'Senkronizasyon başarısız';
      });
    }
  }

  Future<void> _verileriGuncelle() async {
    final connectivity = ref.read(connectivityProvider);
    if (!connectivity.online) {
      if (mounted) {
        showBildirim(context, 'İnternet bağlantısı yok', basarili: false);
      }
      return;
    }

    setState(() {
      _syncing = true;
      _syncStats = 'Veriler güncelleniyor...';
    });

    try {
      final isletmeler = ref.read(isletmeProvider).isletmeler;
      final result = await ref.read(connectivityProvider.notifier).verileriGuncelle(isletmeler);

      setState(() {
        _syncing = false;
        _syncDone = true;
        _syncStats = 'Güncelleme tamamlandı';
      });

      if (mounted) {
        await SyncResultDialog.show(context, result);
      }

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _syncDone = false);
      });
    } catch (e) {
      setState(() {
        _syncing = false;
        _syncStats = 'Güncelleme başarısız';
      });
      if (mounted) {
        showBildirim(context, 'Güncelleme hatası: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}', basarili: false);
      }
    }
  }

  Future<void> _toggleOfflineMode() async {
    final connectivity = ref.read(connectivityProvider);

    if (connectivity.offlineMode) {
      // ── Online moda dön: otomatik push + pull ──
      if (!connectivity.online) {
        if (mounted) {
          showBildirim(context, 'Çevrimiçi moda dönmek için internet gerekli', basarili: false);
        }
        return;
      }

      final bekleyen = connectivity.bekleyenSync;
      final onay = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1B2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Çevrimiçi Moda Dön', style: TextStyle(color: Colors.white)),
          content: Text(
            bekleyen > 0
                ? '$bekleyen bekleyen işlem sunucuya gönderilecek ve taze veriler çekilecek.\n\nDevam etmek istiyor musunuz?'
                : 'Sunucudan taze veriler çekilecek.\n\nDevam etmek istiyor musunuz?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Devam', style: TextStyle(color: Colors.orange))),
          ],
        ),
      );
      if (onay != true) return;

      setState(() {
        _syncing = true;
        _syncStats = bekleyen > 0 ? 'Veriler gönderiliyor...' : 'Veriler çekiliyor...';
      });

      try {
        final isletmeler = ref.read(isletmeProvider).isletmeler;
        final result = await ref.read(connectivityProvider.notifier).exitOfflineMode(isletmeler);

        setState(() {
          _syncing = false;
          _syncDone = true;
          _syncStats = 'Çevrimiçi moda dönüldü';
        });

        if (mounted) {
          if (result.basarili > 0 || result.basarisiz > 0) {
            await SyncResultDialog.show(context, result);
          } else {
            showBildirim(context, 'Çevrimiçi moda dönüldü');
          }
        }

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _syncDone = false);
        });
      } catch (e) {
        setState(() {
          _syncing = false;
          _syncStats = 'Geçiş başarısız';
        });
        if (mounted) {
          showBildirim(context, 'Geçiş hatası: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}', basarili: false);
        }
      }
    } else {
      // ── Offline moda geç: veri indir ──
      if (!connectivity.online) {
        if (mounted) {
          showBildirim(context, 'Offline moda geçmek için önce internet gerekli', basarili: false);
        }
        return;
      }

      final onay = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1B2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Offline Moda Geç', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Tüm veriler telefonunuza indirilecek.\nİnternet olmadan çalışabileceksiniz.\n\nDevam etmek istiyor musunuz?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Devam', style: TextStyle(color: Color(0xFF6C53F5)))),
          ],
        ),
      );
      if (onay != true) return;

      setState(() {
        _syncing = true;
        _syncStats = 'Veriler indiriliyor...';
      });

      try {
        final isletmeler = ref.read(isletmeProvider).isletmeler;
        final stats = await ref.read(connectivityProvider.notifier).enterOfflineMode(isletmeler);
        setState(() {
          _syncing = false;
          _syncDone = true;
          _syncStats = stats.toString();
        });
        if (mounted) {
          showBildirim(context, '✓ ${stats.toString()}', sure: 4);
        }
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _syncDone = false);
        });
      } catch (_) {
        setState(() {
          _syncing = false;
          _syncStats = 'Veri indirme başarısız';
        });
      }
    }
  }

  void _showIsletmeler() {
    final isletme = ref.read(isletmeProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _IsletmelerSheet(
        isletmeler: isletme.isletmeler,
        seciliId: isletme.secili?.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityProvider);
    final isOffline = connectivity.offlineMode;
    final hasPending = connectivity.bekleyenSync > 0;

    // Offline modda "Verileri Güncelle" daima pasif
    final syncEnabled = !isOffline;

    return AppLayout(
      showSettings: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Verileri Güncelle button
            GestureDetector(
              onTap: syncEnabled ? _syncData : null,
              child: Opacity(
                opacity: syncEnabled ? 1.0 : 0.5,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _syncDone
                              ? const Color(0xFF10B981)
                              : isOffline
                                  ? Colors.orange
                                  : const Color(0xFF6C53F5),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: (_syncDone
                                      ? const Color(0xFF10B981)
                                      : isOffline
                                          ? Colors.orange
                                          : const Color(0xFF6C53F5))
                                  .withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _syncing
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : Icon(
                                _syncDone ? Icons.check : Icons.sync,
                                color: Colors.white,
                                size: 22,
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _syncing
                                  ? 'Güncelleniyor...'
                                  : _syncDone
                                      ? 'Tamamlandı!'
                                      : 'Verileri Güncelle',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _syncStats.isNotEmpty
                                  ? _syncStats
                                  : isOffline
                                      ? 'Çevrimiçi moda dönünce aktif olur'
                                      : 'Tüm verileri senkronize et',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOffline
                              ? Colors.orange
                              : connectivity.online
                                  ? (_syncDone ? const Color(0xFF10B981) : const Color(0xFF6C53F5))
                                  : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Offline Mod Toggle button
            GestureDetector(
              onTap: _syncing ? null : _toggleOfflineMode,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isOffline
                      ? Colors.orange.withValues(alpha: 0.1)
                      : const Color(0xFF6C53F5).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isOffline
                        ? Colors.orange.withValues(alpha: 0.3)
                        : const Color(0xFF6C53F5).withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOffline ? Icons.wifi : Icons.wifi_off,
                      color: isOffline ? Colors.orange : const Color(0xFF6C53F5),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isOffline ? 'Çevrimiçi Moda Dön' : 'Offline Moda Geç',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isOffline ? Colors.orange.shade700 : const Color(0xFF6C53F5),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: isOffline ? Colors.orange.withValues(alpha: 0.5) : const Color(0xFF6C53F5).withValues(alpha: 0.4),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Grid Cards
            Expanded(
              child: GridView.count(
              crossAxisCount: 2,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _NavCard(
                  icon: Icons.business,
                  label: 'İşletmeler',
                  onTap: _showIsletmeler,
                ),
                if (ref.read(authProvider.notifier).hasYetki('urun', 'goruntule'))
                  _NavCard(
                    icon: Icons.inventory_2,
                    label: 'Stoklar',
                    onTap: () => context.push('/stoklar'),
                  ),
                if (ref.read(authProvider.notifier).hasYetki('sayim', 'goruntule'))
                  _NavCard(
                    icon: Icons.assignment,
                    label: 'Sayımlar',
                    onTap: () => context.push('/sayimlar'),
                  ),
                if (ref.read(authProvider.notifier).hasYetki('depo', 'goruntule'))
                  _NavCard(
                    icon: Icons.warehouse,
                    label: 'Depolar',
                    onTap: () => context.push('/depolar'),
                  ),
                if (ref.read(authProvider.notifier).hasYetki('toplam_sayim', 'goruntule'))
                  _NavCard(
                    icon: Icons.calculate,
                    label: 'Toplam Sayımlar',
                    onTap: () => context.push('/toplanmis-sayimlar'),
                  ),
              ],
            ),
            ),
          ],
        ),
      ),
    );
  }
}

// Navigation card widget
class _NavCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C53F5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: const Color(0xFF6C53F5), size: 26),
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Isletmeler bottom sheet
class _IsletmelerSheet extends StatelessWidget {
  final List isletmeler;
  final String? seciliId;

  const _IsletmelerSheet({
    required this.isletmeler,
    required this.seciliId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.business, color: Color(0xFF6C53F5), size: 20),
                SizedBox(width: 8),
                Text('İşletmelerim', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: isletmeler.length,
              itemBuilder: (context, index) {
                final i = isletmeler[index];
                final selected = i.id == seciliId;

                final colors = [
                  [const Color(0xFF6C53F5), const Color(0xFF8B5CF6)],
                  [const Color(0xFF0EA5E9), const Color(0xFF2563EB)],
                  [const Color(0xFF10B981), const Color(0xFF059669)],
                  [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                  [const Color(0xFFEC4899), const Color(0xFFDB2777)],
                ];
                final gradColors = colors[index % colors.length];

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF6C53F5).withValues(alpha: 0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: selected
                        ? Border.all(color: const Color(0xFF6C53F5).withValues(alpha: 0.3))
                        : Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: gradColors),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i.ad, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1F2937))),
                            if (i.kod != null && i.kod!.isNotEmpty)
                              Text(i.kod!, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                          ],
                        ),
                      ),
                      if (selected)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
