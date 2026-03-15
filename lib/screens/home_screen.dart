import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/isletme_provider.dart';
import '../providers/connectivity_provider.dart';
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
    setState(() {
      _syncing = true;
      _syncDone = false;
      _syncStats = '';
    });

    try {
      // Yetkileri de sunucudan güncelle
      await ref.read(authProvider.notifier).oturumKontrol();
      await ref.read(isletmeProvider.notifier).yukle();
      final isletme = ref.read(isletmeProvider);
      setState(() {
        _syncing = false;
        _syncDone = true;
        _syncStats = '${isletme.isletmeler.length} işletme senkronize edildi';
      });
      // Reset after 3 seconds
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

    return AppLayout(
      showSettings: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Verileri Güncelle button
            GestureDetector(
              onTap: _syncData,
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
                    // Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _syncDone
                            ? const Color(0xFF10B981)
                            : const Color(0xFF6C53F5),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (_syncDone
                                    ? const Color(0xFF10B981)
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _syncDone ? Icons.check : Icons.sync,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                    const SizedBox(width: 16),
                    // Text
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
                                : 'Tüm verileri senkronize et',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status dot
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: connectivity.online
                            ? (_syncDone
                                ? const Color(0xFF10B981)
                                : const Color(0xFF6C53F5))
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Grid Cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
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
          ],
        ),
      ),
    );
  }
}

// Navigation card widget - matches web design
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
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1,
          ),
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
              // Icon with badge - like web design
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
                    child: Icon(
                      icon,
                      color: const Color(0xFF6C53F5),
                      size: 26,
                    ),
                  ),
                  // Green checkmark badge on icon
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
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
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.business, color: Color(0xFF6C53F5), size: 20),
                SizedBox(width: 8),
                Text(
                  'İşletmelerim',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // List
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: isletmeler.length,
              itemBuilder: (context, index) {
                final i = isletmeler[index];
                final selected = i.id == seciliId;

                // Gradient colors
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
                      color: selected
                          ? const Color(0xFF6C53F5).withValues(alpha: 0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: selected
                          ? Border.all(color: const Color(0xFF6C53F5).withValues(alpha: 0.3))
                          : Border.all(color: const Color(0xFFF3F4F6)),
                    ),
                    child: Row(
                      children: [
                        // Number avatar
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: gradColors),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Name
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                i.ad,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              if (i.kod != null && i.kod!.isNotEmpty)
                                Text(
                                  i.kod!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Active dot
                        if (selected)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
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
