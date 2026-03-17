# StokSay Mobile v4.1.1

Depo sayim yonetim uygulamasinin Flutter mobil istemcisi. Tam offline/online mod destegi ile internet baglantisi olmadan da calismaya devam eder.

## Ozellikler

- **Offline/Online Mod**: Internet olmadan tam CRUD islemleri, sonra senkronizasyon
- **Depo Yonetimi**: Depo ekleme, duzenleme, silme (aktif sayim korumasi ile)
- **Urun/Stok Yonetimi**: Urun ekleme, barkod destegi, duzenleme, silme
- **Sayim Islemleri**: Sayim olusturma, kalem ekleme, tamamlama, birlestirme (topla)
- **Coklu Isletme**: Birden fazla isletme arasinda gecis
- **Senkronizasyon**: Push-first-then-pull stratejisi ile veri tutarliligi
- **Pasif Kullanici Ekrani**: 403 algilama, dark ekran, cikis yap butonu, admin iletisim uyarisi
- **Yetkisiz Kullanici Ekrani**: Dark tema, animasyonlu guncelle butonu, yetki ataninca normale donus
- **Offline Cikis Engeli**: Offline modda cikis yapilarak veri kaybi onlenir
- **Excel (XLSX) Export**: Gercek xlsx formati ile sayim paylasimi

## Teknik Yapi

### Teknolojiler
- **Flutter** 3.x + Dart
- **Riverpod** - State management
- **Dio** - HTTP client
- **sqflite** - SQLite veritabani (offline veri)
- **SharedPreferences** - Yerel ayarlar

### Klasor Yapisi

```
lib/
├── main.dart
├── db/
│   ├── database_helper.dart    # SQLite tablo olusturma ve migration
│   └── sync_service.dart       # Senkronizasyon motoru (push/pull)
├── providers/
│   ├── auth_provider.dart      # Kimlik dogrulama state
│   ├── connectivity_provider.dart  # Offline/online mod yonetimi
│   └── isletme_provider.dart   # Isletme state ve SQLite cache
├── services/
│   ├── api_service.dart        # Dio HTTP yapilandirmasi
│   ├── auth_service.dart       # Login/logout
│   ├── depo_service.dart       # Depo CRUD (offline/online)
│   ├── isletme_service.dart    # Isletme CRUD
│   ├── offline_id_service.dart # Temp ID uretici (temp_-1, temp_-2...)
│   ├── profil_service.dart     # Profil ve istatistikler
│   ├── sayim_service.dart      # Sayim CRUD + kalemler (offline/online)
│   ├── storage_service.dart    # SharedPreferences wrapper
│   └── urun_service.dart       # Urun CRUD (offline/online)
├── screens/
│   ├── app_layout.dart         # Ana layout + offline badge
│   ├── ayarlar_screen.dart     # Ayarlar sayfasi
│   ├── depolar_screen.dart     # Depo listesi ve yonetimi
│   ├── home_screen.dart        # Ana ekran (offline toggle + sync)
│   ├── login_screen.dart       # Giris ekrani
│   ├── sayim_detay_screen.dart # Sayim detay ve kalem islemleri
│   ├── sayimlar_screen.dart    # Sayim listesi
│   ├── shell_screen.dart       # Bottom navigation shell
│   ├── stoklar_screen.dart     # Stok/urun listesi ve yonetimi
│   ├── toplanmis_sayimlar_screen.dart # Birlestirilmis sayimlar
│   ├── urun_ekle_screen.dart   # Urun ekleme formu
│   └── yeni_sayim_screen.dart  # Yeni sayim olusturma
└── widgets/
    ├── aktif_sayim_dialog.dart # Aktif sayim uyari dialogu
    ├── bildirim.dart           # Snackbar bildirim helper
    └── sync_result_dialog.dart # Senkronizasyon sonuc dialogu
```

## Offline Mod Mimarisi

### Gecis Akisi
1. Kullanici "Offline Moda Gec" butonuna basar
2. `ConnectivityProvider.enterOfflineMode()` cagirilir
3. `SyncService.tamSenkronizasyon()` tum verileri SQLite'a indirir
4. `StorageService.isOffline = true` ayarlanir
5. Tum servisler artik SQLite'tan okur/yazar

### Temp ID Sistemi
- Offline eklenen kayitlar `temp_-1`, `temp_-2` gibi string ID alir
- `OfflineIdService` negatif sayac tutar (SharedPreferences)
- Online ID'ler UUID string → cakisma olmaz
- Senkronizasyonda temp ID → gercek ID eslemesi yapilir

### Sync Queue
- Offline yapilan her degisiklik `sync_queue` tablosuna yazilir
- "Verileri Guncelle" basildiginda:
  1. **Push**: Queue'daki islemler sirasi ile sunucuya gonderilir
  2. **Pull**: Sunucudan guncel veriler cekilir
- `_updateQueueRefs`: Temp ID → gercek ID eslesmesini bekleyen queue kayitlarinda gunceller
- `SyncResult` ile kullaniciya basarili/basarisiz islem ozeti gosterilir

### Soft Delete
- Depolar: `aktif = 0` (SQLite) + sync_queue'ya "sil" eklenir
- Sayimlar: `durum = 'silindi'` + sync_queue'ya "sil" eklenir
- Urunler: `aktif = 0` + sync_queue'ya "sil" eklenir
- Senkronizasyonda sunucu tarafinda gercek silme yapilir

### Aktif Sayim Korumasi
- Depo/urun silinirken aktif sayimda kullaniliyorsa `AktifSayimException` firlatilir
- Dialog ile hangi sayimlarda kullanildigi gosterilir
- Hem offline (SQLite sorgusu) hem online (API + backend 409) icin gecerli

## Kurulum

```bash
# Bagimliliklari yukle
flutter pub get

# Gelistirme modunda calistir
flutter run

# APK olustur
flutter build apk --release
```

## Yapilandirma

API adresi `lib/services/api_service.dart` icinde tanimlidir:
- **Production**: `https://stoksay.com/api`
- **Development**: `http://192.168.100.91:3001/api`

## Versiyon Gecmisi

| Versiyon | Aciklama |
|----------|----------|
| v4.1.1 | Pasif kullanici ekrani, yetkisiz ekran, offline cikis engeli, XLSX export |
| v4.0 | Offline/Online mod, senkronizasyon, aktif sayim korumasi |
| v3.3 | Sayim birlestirme, toplu islemler, guvenlik guncellemesi |
| v3.0 | Coklu isletme destegi |
