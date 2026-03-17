# DepoSayim — Depo Sayim ve Stok Yonetim Platformu

Kucuk ve orta olcekli isletmeler icin cok isletmeli, rol tabanli stok ve depo sayim yonetim platformu.

**v4.1.1** — Kullanici Yonetimi + Pasif Kullanici Guvenligi (Mart 2026)

---

## Platform Yapisi

```
deposayim/
├── stoksay/          # Backend API + Admin Paneli (Web)
│   ├── backend/      #   Express.js 4 + MySQL
│   └── frontend/     #   React 18 + Vite 5 + Tailwind
│
├── mobile/           # Mobil Uygulama
│   └── lib/          #   Flutter 3.11 (iOS + Android)
│
├── SECURITY.md'ler   # Her alt projede guvenlik raporu
└── QA-RAPOR-*.md     # QA test raporlari
```

---

## Hizli Bakis

| Bilesen | Teknoloji | Port / Platform | Hedef Kitle |
|---------|-----------|-----------------|-------------|
| **Backend API** | Express.js, MySQL, JWT | `localhost:3001` | Tum istemciler |
| **Admin Paneli** | React, Vite, Zustand, Radix UI | `localhost:5173` | Sistem yoneticileri |
| **Mobil Uygulama** | Flutter, Riverpod, SQLite | iOS / Android | Saha kullanicilari |

### Mimari

```
┌─────────────────┐     ┌─────────────────────┐
│  Admin Paneli    │     │   Flutter Mobil App   │
│  React + Vite    │     │   iOS / Android       │
│  Zustand Store   │     │   Riverpod + SQLite   │
└────────┬────────┘     └──────────┬────────────┘
         │    REST API (JSON + JWT)    │
         └────────────┬────────────────┘
                      │
           ┌──────────▼──────────┐
           │   Express.js API     │
           │   Helmet + CORS      │
           │   Rate Limiting      │
           │   Auth/Admin/Yetki   │
           └──────────┬──────────┘
                      │
           ┌──────────▼──────────┐
           │   MySQL / MariaDB    │
           │   9 tablo + RLS      │
           └─────────────────────┘
```

---

## Ozellikler

### Cekirdek
- Cok isletme destegi — bir kullanici birden fazla isletmede calisabilir
- Granuler rol ve yetki sistemi (isletme bazli, 4 kategori x 4 islem)
- Depo yonetimi (CRUD, konum, kod)
- Urun katalogu (barkod, coklu isim, birim, kategori)
- Sayim oturumlari (baslat → urun ekle → tamamla → topla)
- Sayim birlestirme (toplama)
- Excel (XLSX) toplu urun yukleme + catisma cozumu
- PDF ve Excel rapor ciktisi
- Dashboard istatistikleri ve grafikler

### Mobil
- Kamera ile barkod tarama
- Offline-first mimari (SQLite + senkronizasyon kuyrugu)
- Hesap makinesi entegrasyonu
- Pull-to-refresh, swipe-to-dismiss bildirimler
- Excel (XLSX) ve PDF disa aktarim + paylasim
- Pasif kullanici ekrani (API erisim engeli + uyari)
- Yetkisiz kullanici ekrani (dark tema + animasyonlu guncelle butonu)
- Offline modda cikis engelleme (veri kaybi korumasi)

### Guvenlik (v4.1.1)
- JWT tabanli kimlik dogrulama (7 gun sureli)
- Helmet.js guvenlik basiklari + CSP (Content Security Policy)
- CORS whitelist
- Rate limiting (genel: 1500/15dk, giris: 20/15dk)
- Soft delete — veriler asla silinmez
- IDOR korumasi — sahiplik + yetki cift kontrol
- Transaction ile race condition korumasi (barkod, toplama)
- Input validation (miktar, rol, sifre uzunlugu)
- Hata mesaji sizinti korumasi (err.message gizlenir)

---

## Kurulum

### Gereksinimler
- Node.js 18+
- MySQL 8 veya MariaDB 10+
- Flutter SDK 3.11+ (mobil icin)
- PM2 (onerilen)

### 1. Backend

```bash
cd stoksay/backend
npm install
cp .env.example .env          # Ortam degiskenlerini duzenle
mysql -u root -p < db/schema_mariadb.sql
node seed.js                  # Ilk admin kullanicisi

# Calistirma
pm2 start index.js --name stoksay-backend
```

### 2. Admin Paneli (Frontend)

```bash
cd stoksay/frontend
npm install
npm run dev                   # localhost:5173
```

### 3. Mobil Uygulama

```bash
cd mobile
flutter pub get

# api_config.dart icinde IP adresini ayarla
# lib/config/api_config.dart → _devUrl

flutter run                   # Bagli cihaza yukle
flutter build apk --release   # Android APK
flutter build ios --release   # iOS (Xcode gerekli)
```

---

## Ortam Degiskenleri

`stoksay/backend/.env`:

```env
DB_HOST=localhost
DB_PORT=3306
DB_USER=stoksay
DB_PASS=sifre
DB_NAME=stoksay
PORT=3001
JWT_SECRET=min-32-karakter-gizli-anahtar
ALLOWED_ORIGINS=http://localhost:5173,http://<IP>:3001
```

`mobile/lib/config/api_config.dart`:

```dart
static const String _devUrl = 'http://<BILGISAYAR_IP>:3001/api';
static const String _prodUrl = 'https://stoksay.com/api';
```

---

## Veritabani

9 tablo, UUID primary key, JSONB yetkiler:

| Tablo | Aciklama |
|-------|----------|
| `kullanicilar` | Kullanicilar (email, bcrypt sifre, admin/kullanici rol) |
| `isletmeler` | Isletmeler (ad, kod, adres) |
| `depolar` | Depolar (isletme_id FK, ad, konum) |
| `isletme_urunler` | Urunler (barkod, coklu isim, birim) |
| `sayimlar` | Sayim oturumlari (durum: devam/tamamlandi/silindi) |
| `sayim_kalemleri` | Sayim kalemleri (urun_id, miktar, birim) |
| `kullanici_isletme` | Kullanici-Isletme iliskisi + yetkiler (JSON) |
| `roller` | Rol sablonlari (sistem + ozel) |
| `urun_log` | Urun degisiklik gecmisi |

---

## API Endpointleri

**Base URL:** `http://localhost:3001/api`

| Grup | Endpoint | Yetki |
|------|----------|-------|
| **Auth** | `POST /auth/login`, `GET /auth/me`, `PUT /auth/update-password` | Public / Auth |
| **Sayimlar** | `GET/POST/PUT/DELETE /sayimlar`, `POST /sayimlar/topla` | sayim.* |
| **Kalemler** | `POST/PUT/DELETE /sayimlar/:id/kalem/:kalemId` | Sadece durum=devam |
| **Urunler** | `GET/POST/PUT/DELETE /urunler`, `GET /urunler/barkod/:barkod` | urun.* |
| **Depolar** | `GET/POST/PUT/DELETE /depolar` | depo.* |
| **Isletmeler** | `GET/POST/PUT/DELETE /isletmeler` | Admin |
| **Kullanicilar** | `GET/POST/PUT/DELETE /kullanicilar`, yetki/isletme atama | Admin |
| **Roller** | `GET/POST/PUT/DELETE /roller` | Admin |
| **Profil** | `GET /profil/isletmelerim`, `GET /profil/stats`, `PUT /profil/ayarlar` | Auth |
| **Stats** | `GET /stats`, `/sayim-trend`, `/isletme-sayimlar` | Admin |

---

## Yetki Sistemi

| Rol | Kapsam |
|-----|--------|
| `admin` | Tum islemlere tam erisim |
| `kullanici` | Isletme bazli granuler yetkiler |

### Yetki Matrisi (JSON)

```json
{
  "urun":        { "goruntule": true, "ekle": false, "duzenle": false, "sil": false },
  "depo":        { "goruntule": true, "ekle": false, "duzenle": false, "sil": false },
  "sayim":       { "goruntule": true, "ekle": true,  "duzenle": true,  "sil": false },
  "toplam_sayim": { "goruntule": false, "ekle": false, "duzenle": false, "sil": false }
}
```

---

## Proses Yonetimi

```bash
# Backend
pm2 start stoksay/backend/index.js --name stoksay-backend
pm2 restart stoksay-backend --update-env
pm2 logs stoksay-backend

# Frontend dev
cd stoksay/frontend && npm run dev

# Mobil
cd mobile && flutter run
```

---

## Test Hesaplari

| Hesap | Email | Sifre | Rol |
|-------|-------|-------|-----|
| Admin | admin@stoksay.com | TestAdmin123 | admin |
| Demo | demo001@stoksay.demo | 123 | kullanici |

---

## Guvenlik Raporlari

Her alt projede SECURITY.md dosyasi bulunur:

- `stoksay/SECURITY.md` — Backend + Frontend guvenlik denetimi
- `mobile/SECURITY.md` — Flutter mobil guvenlik denetimi
- `QA-RAPOR-2026-03-16.md` — Son QA test raporu

### Son Guvenlik Guncellemesi (v3.3 — 2026-03-16)

16 guvenlik acigi kapatildi:

| Oncelik | Sayi | Ornekler |
|---------|------|----------|
| **Kritik** | 3 | Async handler crash korumasi, isletme_ids yetki bypass, yetkiGuard null check |
| **Yuksek** | 4 | err.message sizinti, barkod race condition (transaction), toplama race condition, rol silme atomik islem |
| **Orta** | 7 | Sifre min uzunluk, rol validation, miktar validation, rate limit, CSP, ad_soyad crash, Flutter JSON parse |
| **Dusuk** | 2 | error→hata tutarliligi, ek input dogrulama |

---

## Surum Gecmisi

| Surum | Tarih | Aciklama |
|-------|-------|----------|
| **v4.1.1** | 2026-03-17 | Pasif kullanici guvenligi, rol kaldirma yetki sifirlama, admin panel iyilestirmeleri |
| **v4.0** | 2026-03-17 | Offline/online mod, senkronizasyon, aktif sayim korumasi |
| **v3.3** | 2026-03-16 | 16 guvenlik acigi kapatildi, QA test raporu |
| **v3.2** | 2026-03-16 | CSP aktif, Helmet.js, guvenlik iyilestirmeleri |
| **v3.1** | 2026-03-15 | Sayim ID gosterim, flutter_secure_storage |
| **v3** | 2026-03-15 | Web app kaldirildi, sadece admin paneli |
| **v2** | 2026-03-14 | Flutter mobil, offline-first, barkod tarayici |
| **v1** | 2026-03-12 | Ilk kararli surum |

---

## Repolar

| Repo | URL |
|------|-----|
| Backend + Admin | [github.com/Hasanheybat/stoksayim](https://github.com/Hasanheybat/stoksayim) |
| Mobil Uygulama | [github.com/Hasanheybat/stoksay-mobile](https://github.com/Hasanheybat/stoksay-mobile) |

---

## Lisans

Bu proje ozel kullanim icindir.
