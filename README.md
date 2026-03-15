# StokSay Mobil — Depo Sayim Uygulamasi

Flutter ile gelistirilmis, iOS ve Android destekli mobil depo sayim uygulamasi. Offline-first mimaride calisir.

**v3** — StokSay Mobil Uygulama

---

## Icindekiler

- [Genel Bakis](#genel-bakis)
- [Ozellikler](#ozellikler)
- [Kurulum](#kurulum)
- [Ekranlar](#ekranlar)
- [Mimari](#mimari)
- [Servis Katmani](#servis-katmani)
- [Veri Modelleri](#veri-modelleri)
- [Offline Destek ve Senkronizasyon](#offline-destek-ve-senkronizasyon)
- [Barkod Tarayici](#barkod-tarayici)
- [Bildirim Sistemi](#bildirim-sistemi)
- [Yetki Sistemi](#yetki-sistemi)
- [Kullanici Ayarlari](#kullanici-ayarlari)
- [Bagimliliklar](#bagimliliklar)
- [Dizin Yapisi](#dizin-yapisi)
- [Surum Gecmisi](#surum-gecmisi)

---

## Genel Bakis

StokSay Mobil, saha kullanicilari icin tasarlanmis bir depo sayim uygulamasidir. Backend API ile haberlesir ve internet olmadan da calismaya devam eder.

| Ozellik | Detay |
|---------|-------|
| **Platform** | iOS, Android |
| **Framework** | Flutter 3.11+ |
| **State Yonetimi** | Riverpod 3.3 |
| **Yonlendirme** | GoRouter 17.1 |
| **HTTP** | Dio 5.9 |
| **Yerel DB** | SQLite (sqflite 2.4) |
| **Backend** | [stoksay](https://github.com/Hasanheybat/stoksayim) Express.js API |
| **Tema** | Material 3, Ana renk: #6C53F5 (Mor) |

---

## Ozellikler

### Cekirdek
- Cok isletme destegi — isletmeler arasi gecis
- Sayim olusturma, duzenleme, tamamlama, silme
- Sayimlari birlestirme (toplama)
- Urun katalogu goruntulemesi ve arama
- Depo yonetimi
- PDF ve CSV disa aktarim + paylasim

### Barkod & Urun Ekleme
- Kamera ile barkod tarama (mobile_scanner)
- Otomatik urun tamamlama (debounced arama, 300ms)
- Hesap makinesi entegrasyonu (miktar icin)
- Titresim geri bildirimi (barkod okuma)
- Urun kodu ve barkod chip gorunumu

### Offline-First
- Yerel SQLite veritabani
- Senkronizasyon kuyrugu (sync_queue)
- Otomatik baglanti izleme (connectivity_plus)
- Online olunca otomatik kuyruk gonderimi
- Kullanici ve yetki bilgisi cache'leme

### UX
- Overlay tabanli bildirimler (yesil/kirmizi/mor)
- Swipe-to-dismiss bildirimler
- Gradient tasarim (mor tema)
- Bottom sheet modal'lar
- Pull-to-refresh

---

## Kurulum

### Gereksinimler
- Flutter SDK 3.11+
- Xcode (iOS icin)
- Android Studio (Android icin)
- Calisan StokSay Backend API

### Adimlar

```bash
# Bagimliliklari yukle
cd mobile
flutter pub get

# API adresini yapilandir
# lib/config/api_config.dart dosyasinda baseUrl degerini duzenleyin

# iOS cihaza yukleme
flutter run -d <cihaz_id>

# Android cihaza yukleme
flutter run

# Release build
flutter build ios --release
flutter build apk --release
```

### API Yapilandirmasi

`lib/config/api_config.dart` dosyasinda:

| Ortam | URL |
|-------|-----|
| Emulator | `http://localhost:3001/api` |
| Fiziksel cihaz (ayni ag) | `http://<bilgisayar_ip>:3001/api` |
| Uretim | `https://api.domain.com/api` |

---

## Ekranlar

| Yol | Ekran | Aciklama |
|-----|-------|----------|
| `/login` | LoginScreen | Email + sifre ile giris, otomatik oturum kontrolu |
| `/` | HomeScreen | Ana sayfa — senkronizasyon butonu, navigasyon kartlari, isletme secici |
| `/sayimlar` | SayimlarScreen | Sayim listesi — filtre (tumu/devam/tamamlandi), toplu secim + toplama |
| `/sayim/:id` | SayimDetayScreen | Sayim detayi — kalem listesi, duzenleme, silme, PDF export |
| `/yeni-sayim` | YeniSayimScreen | Yeni sayim olustur — isletme, depo, tarih, kisiler secimi |
| `/sayim/:id/urun-ekle` | UrunEkleScreen | Urunu sayima ekle — barkod, arama, hesap makinesi |
| `/stoklar` | StoklarScreen | Urun katalogu — arama, sayfalama |
| `/depolar` | DepolarScreen | Depo listesi — arama, ekleme |
| `/toplanmis-sayimlar` | ToplanmisSayimlarScreen | Birlestirilmis sayimlar — isim duzenleme, silme |
| `/ayarlar` | AyarlarScreen | Kullanici tercihleri — birim otomatik, barkod sesi |

### Ekran Akislari

```
Login → Home → Sayimlar → Sayim Detay → Urun Ekle
                    │                        │
                    │                   Barkod Tara
                    │                   Urun Ara
                    │                   Miktar Gir
                    │                   Hesap Makinesi
                    │
                    ├→ Yeni Sayim → (otomatik) Urun Ekle
                    │
                    ├→ Toplama Modu → Secili sayimlari birlestir
                    │
         Home → Stoklar → Urun Arama
                    │
         Home → Depolar → Depo Ekleme
                    │
         Home → Ayarlar → Toggle tercihler
```

---

## Mimari

### State Yonetimi (Riverpod)

Uc ana provider bulunur:

#### AuthProvider — Kimlik Dogrulama

```dart
class AuthState {
  Kullanici? kullanici;              // Kullanici bilgileri
  Map<String, dynamic> yetkilerMap;  // Isletme bazli yetki haritasi
  bool yukleniyor;
  String? hata;
}

// Metodlar
girisYap(email, sifre)                              // JWT token al
oturumKontrol()                                      // Token dogrula
cikisYap()                                           // Token sil
hasYetki(kategori, islem)                            // Herhangi bir isletmede yetki
isletmeYetkisi(isletmeId, kategori, islem)           // Belirli isletmede yetki
```

#### IsletmeProvider — Isletme Secimi

Secili isletme bilgisini tutar. Tum veri sorgulari secili isletmeye gore filtrelenir.

#### ConnectivityProvider — Ag Durumu

Baglanti durumunu gercek zamanli izler. Online olunca senkronizasyon kuyrugunu tetikler.

### API Katmani (Dio)

```dart
// Her istekte JWT token eklenir
options.headers['Authorization'] = 'Bearer $token';

// Timeout: 10 saniye (connect + receive)
// 401 yanitinda otomatik cikis
```

---

## Servis Katmani

Tum servisler `lib/services/` altinda yer alir.

| Servis | Dosya | Aciklama |
|--------|-------|----------|
| ApiService | `api_service.dart` | Dio HTTP istemcisi — JWT interceptor, timeout, hata yonetimi |
| StorageService | `storage_service.dart` | SharedPreferences sarmalayici — token saklama |
| AuthService | `auth_service.dart` | Giris / cikis / oturum kontrolu |
| SayimService | `sayim_service.dart` | Sayim CRUD + kalemler + tamamlama + toplama |
| UrunService | `urun_service.dart` | Urun CRUD + barkod ile arama |
| DepoService | `depo_service.dart` | Depo CRUD |
| IsletmeService | `isletme_service.dart` | Isletme listesi |
| ProfilService | `profil_service.dart` | Istatistikler + ayar guncelleme |

---

## Veri Modelleri

Tum modeller `lib/models/` altinda, `fromJson` / `toJson` destegi ile:

| Model | Dosya | Onemli Alanlar |
|-------|-------|----------------|
| Kullanici | `kullanici.dart` | id, adSoyad, email, rol, aktif, ayarlar |
| Isletme | `isletme.dart` | id, ad, kod, aktif |
| Depo | `depo.dart` | id, ad, konum, isletmeId, aktif |
| Urun | `urun.dart` | id, isletmeId, urunKodu, urunAdi, isim2, birim, barkodlar |
| Sayim | `sayim.dart` | id, isletmeId, depoId, ad, tarih, durum, kisiler, notlar |
| SayimKalemi | `sayim_kalemi.dart` | id, sayimId, urunId, miktar, birim |

---

## Offline Destek ve Senkronizasyon

### Yerel Veritabani (SQLite)

`lib/db/database_helper.dart` ile yonetilir:

```sql
-- Ana tablolar (sunucudan senkronize)
isletmeler       (id, ad, kod, aktif, son_guncelleme)
depolar          (id, isletme_id, ad, konum, aktif, son_guncelleme)
urunler          (id, isletme_id, urun_kodu, urun_adi, isim_2, birim, kategori, barkodlar, aktif)
sayimlar         (id, isletme_id, depo_id, ad, tarih, durum, kullanici_id, kisiler, notlar)
sayim_kalemleri  (id, sayim_id, urun_id, miktar, birim, notlar)

-- Kullanici onbellegi
kullanici_cache  (id, kullanici [JSON], yetkiler_map [JSON])

-- Offline islem kuyrugu
sync_queue       (id AUTOINCREMENT, tablo, islem, veri [JSON], olusturma, durum)
                 durum: 'bekliyor' | 'gonderiliyor' | 'hata'
```

### Senkronizasyon Akisi

```
1. Tam Senkronizasyon (tamSenkronizasyon)
   ├── Her isletme icin:
   │   ├── Depolari cek → SQLite'a yaz (REPLACE)
   │   ├── Urunleri cek → SQLite'a yaz (REPLACE)
   │   └── Sayimlari cek → SQLite'a yaz (REPLACE)
   └── Kullanici bilgisini cache'le

2. Kuyruk Yonetimi
   ├── Offline islem → kuyruguEkle() → sync_queue'ya INSERT
   └── Online olunca → kuyruguGonder()
       ├── 'bekliyor' durumundaki kayitlari oku
       ├── Sirayla backend'e gonder
       ├── Basariliysa: kayit sil
       ├── Gecici ID'leri sunucu ID'leri ile degistir
       └── Hataliysa: durum = 'hata' olarak isaretle

3. Baglanti Izleme
   └── ConnectivityProvider
       ├── Online → otomatik kuyruguGonder() tetikle
       └── Offline → islemleri kuyruguEkle() ile kaydet
```

### Gecici ID Stratejisi

Offline olusturulan kayitlar icin negatif ID kullanilir:
- `-DateTime.now().millisecondsSinceEpoch`
- Senkronizasyonda sunucu ID'si ile degistirilir
- Bagli kayitlardaki (orn. sayim_kalemleri) referanslar da guncellenir

---

## Barkod Tarayici

`mobile_scanner` paketi ile kamera uzerinden barkod okuma. UrunEkleScreen'de kullanilir.

### Akis

```
1. Kamera acilir → barkod taranir
2. GET /api/urunler/barkod/:barkod ile urun aranir
3. Urun bulunursa → form alanlari otomatik doldurulur
4. Titresim geri bildirimi (vibration paketi)
5. Urun bulunamazsa → hata bildirimi
```

### Urun Ekleme Ekrani Detaylari

- **Otomatik Tamamlama:** 300ms debounce ile API'den arama, dropdown sonuc listesi
- **Birim Secici:** Otomatik mod (urun birimi otomatik gelir) veya manuel mod (bottom sheet)
- **Hesap Makinesi:** Miktar alanina dokunulunca acilir, toplama/cikarma/carpma/bolme
- **Coklu Barkod:** Urun kodlari ve barkodlar chip olarak gosterilir

---

## Bildirim Sistemi

`lib/widgets/bildirim.dart` — Overlay tabanli toast bildirimler.

### Bildirim Tipleri

| Tip | Renk | Kullanim |
|-----|------|----------|
| `basarili` | Yesil (#10B981) | Ekleme islemleri — urun eklendi, sayim olusturuldu |
| `hata` | Kirmizi (#EF4444) | Silme islemleri, hatalar — kalem silindi, hata mesajlari |
| `bilgi` | Mor (#6C53F5) | Guncelleme islemleri — miktar guncellendi, ayar degistirildi |

### Animasyon

- **Giris:** Sagdan sola SlideTransition + FadeTransition (300ms)
- **Cikis:** Saga dogru kayarak kaybolma (300ms)
- **Sure:** 2 saniye (ozellestirilebilir)
- **Etkilesim:** Sola kaydirarak kapatma (swipe-to-dismiss)
- **Konum:** Sag ust kose, `top: 60px`, `right: 16px`
- **Davranis:** Ayni anda sadece bir bildirim, yenisi eskisini kapatir

### Kullanim

```dart
// Yesil — ekleme
showBildirim(context, 'Urun sayima eklendi!');

// Kirmizi — silme
showBildirim(context, 'Sayim silindi', tip: BildirimTip.hata);

// Mor — guncelleme
showBildirim(context, 'Stok guncellendi', tip: BildirimTip.bilgi);
```

---

## Yetki Sistemi

Mobil uygulama backend ile ayni yetki yapisini kullanir.

### Roller

| Rol | Kapsam |
|-----|--------|
| `admin` | Tum islemlere tam erisim |
| `kullanici` | Isletme bazli granuler yetkiler |

### Yetki Kategorileri

| Kategori | Islemler |
|----------|----------|
| `urun` | goruntule, ekle, duzenle, sil |
| `depo` | goruntule, ekle, duzenle, sil |
| `sayim` | goruntule, ekle, duzenle, sil |
| `toplam_sayim` | goruntule, ekle, duzenle, sil |

### Kullanim

```dart
// Herhangi bir isletmede yetki kontrolu
if (authState.hasYetki('sayim', 'ekle')) {
  // "Yeni Sayim" butonunu goster
}

// Belirli isletmede yetki kontrolu
if (authState.isletmeYetkisi(isletmeId, 'urun', 'goruntule')) {
  // Urun listesini goster
}
```

> **Not:** Sayim kalem ekleme, duzenleme ve silme islemleri yetki gerektirmez.

---

## Kullanici Ayarlari

AyarlarScreen'de toggle ile degistirilir. `PUT /api/profil/ayarlar` ile sunucuya kaydedilir.

| Ayar | Varsayilan | Aciklama |
|------|------------|----------|
| `birim_otomatik` | `true` | Urun secilince birim otomatik doldurulur |
| `barkod_sesi` | `true` | Barkod okuyunca titresim geri bildirimi |

---

## Bagimliliklar

| Paket | Surum | Kullanim |
|-------|-------|----------|
| flutter_riverpod | ^3.3.1 | State yonetimi |
| go_router | ^17.1.0 | Deklaratif yonlendirme |
| dio | ^5.9.2 | HTTP istemcisi |
| sqflite | ^2.4.2 | Yerel SQLite veritabani |
| connectivity_plus | ^7.0.0 | Ag baglanti durumu izleme |
| mobile_scanner | ^7.2.0 | Kamera ile barkod tarama |
| shared_preferences | ^2.5.4 | Genel tercih depolama |
| flutter_secure_storage | ^9.2.4 | Sifreli token depolama (Keystore/Keychain) |
| intl | ^0.20.2 | Tarih/sayi formatlama |
| path_provider | ^2.1.5 | Dosya sistemi yollari |
| share_plus | ^12.0.1 | Platform paylasim diyalogu |
| pdf | ^3.11.3 | PDF olusturma |
| csv | ^7.2.0 | CSV disa aktarim |
| vibration | ^3.1.8 | Titresim geri bildirimi |

---

## Dizin Yapisi

```
mobile/
├── pubspec.yaml                        # Flutter bagimliliklari
├── ios/                                # iOS platform dosyalari
├── android/                            # Android platform dosyalari
└── lib/
    ├── main.dart                       # Giris noktasi (StorageService init)
    ├── app.dart                        # GoRouter + MaterialApp temasi
    ├── config/
    │   └── api_config.dart             # API URL, timeout, token key
    ├── models/
    │   ├── kullanici.dart
    │   ├── isletme.dart
    │   ├── depo.dart
    │   ├── urun.dart
    │   ├── sayim.dart
    │   └── sayim_kalemi.dart
    ├── services/
    │   ├── api_service.dart            # Dio HTTP istemcisi
    │   ├── storage_service.dart        # SharedPreferences
    │   ├── auth_service.dart           # Giris / cikis
    │   ├── sayim_service.dart          # Sayim CRUD + kalemler
    │   ├── urun_service.dart           # Urun CRUD + barkod
    │   ├── depo_service.dart           # Depo CRUD
    │   ├── isletme_service.dart        # Isletme listesi
    │   └── profil_service.dart         # Ayarlar + istatistik
    ├── db/
    │   ├── database_helper.dart        # SQLite sema + CRUD
    │   └── sync_service.dart           # Senkronizasyon + kuyruk
    ├── providers/
    │   ├── auth_provider.dart          # Kimlik dogrulama state
    │   ├── isletme_provider.dart       # Secili isletme state
    │   └── connectivity_provider.dart  # Ag baglanti durumu
    ├── screens/
    │   ├── login_screen.dart
    │   ├── home_screen.dart
    │   ├── sayimlar_screen.dart
    │   ├── sayim_detay_screen.dart
    │   ├── yeni_sayim_screen.dart
    │   ├── urun_ekle_screen.dart
    │   ├── stoklar_screen.dart
    │   ├── depolar_screen.dart
    │   ├── toplanmis_sayimlar_screen.dart
    │   ├── ayarlar_screen.dart
    │   ├── app_layout.dart
    │   └── shell_screen.dart
    └── widgets/
        └── bildirim.dart               # Overlay bildirim sistemi
```

---

## Surum Gecmisi

### v3.1 — 2026-03-15

- JWT token artik sifrelenmis depolanir (flutter_secure_storage — Android Keystore / iOS Keychain)
- API yapilandirmasi prod/dev ortam ayrimini destekler (HTTPS/HTTP)
- Sayim ID gosterimi ve kopyalama ozelligi
- Sayim toplama bug fix (toplanan sayim artik sadece toplam sayimlarda gorunur)

> **DIKKAT — Production Deployment:**
> `ios/Runner/Info.plist` dosyasinda `NSAllowsArbitraryLoads` ayari development icin `true` olarak ayarlanmistir. Production'a yuklerken bu ayari kaldirin ve sadece gerekli domainler icin exception tanimlayin:
> ```xml
> <key>NSAppTransportSecurity</key>
> <dict>
>     <key>NSExceptionDomains</key>
>     <dict>
>         <key>stoksay.com</key>
>         <dict>
>             <key>NSIncludesSubdomains</key>
>             <true/>
>         </dict>
>     </dict>
> </dict>
> ```
> Ayrica `lib/config/api_config.dart` dosyasinda `_prodUrl` degerini gercek domain adresinizle degistirin ve build sirasinda `--dart-define=PROD=true` parametresini ekleyin:
> ```bash
> flutter build ios --release --dart-define=PROD=true
> flutter build apk --release --dart-define=PROD=true
> ```

### v3 — 2026-03-15

- Kalem duzenleme/silme yetki kontrolu kaldirildi
- Kalem miktar guncelleme hatasi duzeltildi (Navigator.pop oncesi text kaydetme)
- Backend dynamic SQL ile kalem guncelleme duzeltmesi

### v2 — 2026-03-14

- Offline-first mimari altyapisi (SQLite + sync_queue)
- Barkod tarayici entegrasyonu
- Overlay bildirim sistemi (yesil/kirmizi/mor)
- Hesap makinesi entegrasyonu
- Birim otomatik/manuel secim ayari
- PDF ve CSV disa aktarim

### v1 — 2026-03-12

- Ilk kararli surum
- Sayim olusturma, duzenleme, tamamlama
- Urun ve depo yonetimi
- Riverpod state yonetimi
- GoRouter yonlendirme

---

## Lisans

Bu proje ozel kullanim icindir.

---

## Ilgili Repolar

- **Backend + Admin Paneli:** [stoksayim](https://github.com/Hasanheybat/stoksayim)
