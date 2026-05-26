import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import '../models/kullanici.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/socket_service.dart';
import '../db/database_helper.dart';

class AuthState {
  final Kullanici? kullanici;
  final Map<String, dynamic> yetkilerMap;
  final bool yukleniyor;
  final String? hata;
  final bool cacheFallback;
  final bool pasif; // Kullanıcı pasife alınmış mı

  AuthState({
    this.kullanici,
    this.yetkilerMap = const {},
    this.yukleniyor = true,
    this.hata,
    this.cacheFallback = false,
    this.pasif = false,
  });

  AuthState copyWith({
    Kullanici? kullanici,
    Map<String, dynamic>? yetkilerMap,
    bool? yukleniyor,
    String? hata,
    bool? cacheFallback,
    bool? pasif,
  }) {
    return AuthState(
      kullanici: kullanici ?? this.kullanici,
      yetkilerMap: yetkilerMap ?? this.yetkilerMap,
      yukleniyor: yukleniyor ?? this.yukleniyor,
      hata: hata,
      cacheFallback: cacheFallback ?? this.cacheFallback,
      pasif: pasif ?? this.pasif,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  AppLifecycleListener? _lifecycleListener;
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  bool _observerInited = false;
  DateTime? _lastRefresh;

  @override
  AuthState build() {
    // Notifier dispose oldugunda subscription'lari temizle
    ref.onDispose(() {
      _socketSub?.cancel();
      _socketSub = null;
      _lifecycleListener?.dispose();
      _lifecycleListener = null;
    });
    return AuthState();
  }

  /// Throttle: ardisik cagrilarda gereksiz API spam'i onler
  void _refreshThrottled() {
    final now = DateTime.now();
    if (_lastRefresh != null && now.difference(_lastRefresh!).inSeconds < 3) {
      return;
    }
    _lastRefresh = now;
    if (StorageService.hasToken) {
      oturumKontrol();
    }
  }

  /// App foreground'a geldiğinde yetkileri yeniden kontrol eder
  /// Ayrica socket'ten yetki guncelleme event'lerini dinler
  /// IDEMPOTENT — bircok kez cagrilsa bile bir kez kurulum yapar
  void initLifecycleObserver() {
    if (_observerInited) return;
    _observerInited = true;

    try {
      _lifecycleListener = AppLifecycleListener(
        onResume: _refreshThrottled,
      );
    } catch (e) {
      // AppLifecycleListener cold-start'ta hata verebilir, sessizce gec
    }

    // Socket yetki event listener — web'den rol/isletme degistiginde tazele
    try {
      _socketSub = SocketService.events.listen((ev) {
        final type = ev['type'] as String?;
        if (type == 'kullanici:yetki_guncellendi' ||
            type == 'kullanici:isletme_atandi' ||
            type == 'kullanici:isletme_kaldirildi' ||
            type == 'kullanici:pasif') {
          _refreshThrottled();
        }
      });
    } catch (_) {}
  }

  Future<void> oturumKontrol() async {
    state = state.copyWith(yukleniyor: true, hata: null);

    if (!StorageService.hasToken) {
      final cached = await _cacheOku();
      if (cached != null) {
        state = AuthState(
          kullanici: cached['kullanici'],
          yetkilerMap: cached['yetkilerMap'],
          yukleniyor: false,
        );
        return;
      }
      state = AuthState(yukleniyor: false);
      return;
    }

    // Offline moddayken API çağrısı atla, cache'den yükle (timeout beklemeyi önler)
    if (StorageService.isOffline) {
      final cached = await _cacheOku();
      if (cached != null) {
        state = AuthState(
          kullanici: cached['kullanici'],
          yetkilerMap: cached['yetkilerMap'],
          yukleniyor: false,
        );
        return;
      }
      // Cache yoksa normal akışa devam et (API dener)
    }

    try {
      final data = await AuthService.oturumKontrol();
      final kullanici = Kullanici.fromJson(data['kullanici']);
      final yetkilerMap = Map<String, dynamic>.from(data['yetkilerMap'] ?? {});
      try { await _cacheYaz(kullanici, yetkilerMap); } catch (_) {}
      state = AuthState(kullanici: kullanici, yetkilerMap: yetkilerMap, yukleniyor: false);
      try { await SocketService.connect(); } catch (_) {}
    } catch (e) {
      final status = e is DioException ? e.response?.statusCode : null;

      // 403 = kullanıcı pasife alınmış → cache'e düşürme, pasif ekranı göster
      if (status == 403) {
        final cached = await _cacheOku();
        state = AuthState(
          kullanici: cached?['kullanici'],
          yetkilerMap: const {},
          yukleniyor: false,
          pasif: true,
        );
        return;
      }

      Map<String, dynamic>? cached;
      try { cached = await _cacheOku(); } catch (_) {}

      if (cached != null) {
        // Cache var → eski yetkilerle calismaya devam et (fallback uyarisi ile)
        state = AuthState(
          kullanici: cached['kullanici'],
          yetkilerMap: cached['yetkilerMap'],
          yukleniyor: false,
          cacheFallback: true,
        );
        return;
      }

      // Cache yok — sadece 401 (gercekten gecersiz token) durumunda token sil
      // 500/timeout/network gibi gecici hatalarda token korunmali ki kullanici
      // sonsuz "Yukleniyor..." ekraninda kilitlenmesin
      if (status == 401) {
        await StorageService.removeToken();
        state = AuthState(yukleniyor: false, hata: 'Oturum dogrulanamadi');
      } else {
        // 500/network/timeout — token koru, hata mesaji goster
        state = AuthState(
          yukleniyor: false,
          hata: 'Sunucuya ulasilamadi. Tekrar deneyin.',
        );
      }
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(yukleniyor: true, hata: null);
    try {
      await AuthService.login(email, password);
      await oturumKontrol();
      // Socket baglantisini ac (denetleme + canli sync)
      try { await SocketService.connect(); } catch (_) {}
      return true;
    } catch (e) {
      String hata = 'Giris basarisiz';
      if (e is DioException && e.response != null) {
        final status = e.response?.statusCode;
        if (status == 401) hata = 'Email veya sifre hatali';
        if (status == 403) hata = 'Hesabiniz pasif durumdadir';
        if (status == 429) hata = 'Cok fazla deneme. Lutfen bekleyin.';
      }
      state = AuthState(yukleniyor: false, hata: hata);
      return false;
    }
  }

  Future<void> cikisYap() async {
    try { await SocketService.disconnect(); } catch (_) {}
    await AuthService.logout();
    await DatabaseHelper.clearAll();
    state = AuthState(yukleniyor: false);
  }

  void ayarlarGuncelle(Map<String, dynamic> yeniAyarlar) {
    final k = state.kullanici;
    if (k == null) return;
    final yeniKullanici = Kullanici(
      id: k.id,
      adSoyad: k.adSoyad,
      email: k.email,
      rol: k.rol,
      aktif: k.aktif,
      ayarlar: yeniAyarlar,
      denetleyiciYetkisi: k.denetleyiciYetkisi,
      sadeceDenetleyici: k.sadeceDenetleyici,
      izlemeLimitSaniye: k.izlemeLimitSaniye,
    );
    state = state.copyWith(kullanici: yeniKullanici);
    // Cache'i de güncelle
    try { _cacheYaz(yeniKullanici, state.yetkilerMap); } catch (_) {}
  }

  bool hasYetki(String kategori, String islem) {
    final k = state.kullanici;
    if (k == null) return false;
    if (k.rol == 'admin') return true;
    return state.yetkilerMap.values.any((y) {
      if (y is Map) {
        final kat = y[kategori];
        if (kat is Map) return kat[islem] == true;
      }
      return false;
    });
  }

  bool isletmeYetkisi(String isletmeId, String kategori, String islem) {
    final k = state.kullanici;
    if (k == null) return false;
    if (k.rol == 'admin') return true;
    final y = state.yetkilerMap[isletmeId];
    if (y is Map) {
      final kat = y[kategori];
      if (kat is Map) return kat[islem] == true;
    }
    return false;
  }

  Future<void> _cacheYaz(Kullanici kullanici, Map<String, dynamic> yetkilerMap) async {
    final db = await DatabaseHelper.database;
    await db.insert('kullanici_cache', {
      'id': 1,
      'kullanici': jsonEncode(kullanici.toJson()),
      'yetkiler_map': jsonEncode(yetkilerMap),
      'son_guncelleme': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> _cacheOku() async {
    try {
      final db = await DatabaseHelper.database;
      final result = await db.query('kullanici_cache', where: 'id = 1');
      if (result.isEmpty) return null;
      final row = result.first;
      return {
        'kullanici': Kullanici.fromJson(jsonDecode(row['kullanici'] as String)),
        'yetkilerMap': Map<String, dynamic>.from(jsonDecode(row['yetkiler_map'] as String)),
      };
    } catch (_) {
      return null;
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
