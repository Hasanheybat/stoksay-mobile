# StokSay Mobil — Guvenlik Raporu

**Son Tarama:** 2026-03-15
**Kapsam:** Flutter Mobil Uygulama (iOS + Android)

---

## Mevcut Guvenlik Onlemleri (Aktif)

| Onlem | Durum | Detay |
|-------|-------|-------|
| Token depolama | OK | FlutterSecureStorage (Android Keystore / iOS Keychain) |
| Token sifreleme (Android) | OK | `encryptedSharedPreferences: true` |
| Token sifreleme (iOS) | OK | `KeychainAccessibility.first_unlock` |
| Prod/Dev ortam ayrimi | OK | `api_config.dart` — PROD=true ile HTTPS, varsayilan HTTP (dev) |
| Auth guard (GoRouter) | OK | Token yoksa `/login`'e yonlendirme |
| Logout temizlik | OK | `DatabaseHelper.clearAll()` — tum SQLite tablolari temizleniyor |
| 401 otomatik cikis | OK | Dio interceptor ile gecersiz token'da otomatik logout |
| Hardcoded secret yok | OK | Kaynak kodda API key, sifre, secret bulunmuyor |
| Hassas veri loglama yok | OK | Token veya sifre print/debugPrint ile loglanmiyor |
| Deep link saldiri yuzeyi yok | OK | Deep link / URL scheme tanimlanmamis |

---

## Bilinen Aciklar

### YUKSEK

#### Y1 — iOS App Transport Security (ATS) Devre Disi

- **Dosya:** `ios/Runner/Info.plist` satir 52-53
- **Risk:** `NSAllowsArbitraryLoads: true` — tum HTTP (sifrelenmemis) baglantilara izin veriyor. Apple App Store red sebebi olabilir.
- **Gercek etki:** Development icin gerekli (local HTTP backend'e baglanmak icin). Production build'de kaldirmak SART.
- **Deploy'da duzeltilecek:** EVET — Asagidaki yapilandirma uygulanacak:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>stoksay.com</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

#### Y2 — SSL Certificate Pinning Yok

- **Dosya:** Tum codebase'de eksik
- **Risk:** Man-in-the-middle (MITM) saldirisi. Sahte CA sertifikasi yuklenmis cihazda (kurumsal proxy, ele gecirilmis ag) API trafigi okunabilir.
- **Gercek etki:** ORTA — Saldirganin cihaza CA sertifikasi yuklemesi veya ag kontrolu ele gecirmesi gerekir.
- **Cozum:** Dio `HttpClientAdapter` uzerinde `badCertificateCallback` ile sertifika pinleme veya `dio_certificate_pinning` paketi.
- **Deploy'da duzeltilecek:** HAYIR — Ayri sprint'te planlanmali. Sertifika yenileme sureci de olusturulmali.

#### Y3 — Dev URL Plaintext HTTP + Varsayilan Mod Dev

- **Dosya:** `lib/config/api_config.dart` satir 4, 7
- **Risk:** `_isProd` varsayilan `false`. Build sirasinda `--dart-define=PROD=true` unutulursa tum API trafigi sifrelenmemis HTTP uzerinden gider. Ayrica `http://172.22.23.243:3001` internal IP adresi binary'de kalir.
- **Deploy'da duzeltilecek:** EVET — Build komutu:
```bash
flutter build ios --release --dart-define=PROD=true
flutter build apk --release --dart-define=PROD=true
```

#### Y4 — Release Build Debug Key ile Imzali

- **Dosya:** `android/app/build.gradle.kts` satir 37
- **Risk:** `signingConfig = signingConfigs.getByName("debug")` — Release APK debug keystore ile imzalaniyor. Google Play Store kabul etmez. Sideload dagitimda kimlik dogrulamasi yok.
- **Deploy'da duzeltilecek:** EVET — Release keystore olusturulacak:
```bash
keytool -genkey -v -keystore stoksay-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias stoksay
```
`build.gradle.kts`'te release signingConfig ayarlanacak. Keystore dosyasi versiyon kontrolune EKLENMEMELI.

---

### ORTA

#### O1 — Kod Obfuscation / ProGuard Yok

- **Dosya:** `android/app/build.gradle.kts` satir 33-39
- **Risk:** Release APK/IPA unobfuscated Dart kodu iceriyor. API URL'leri, endpoint yollari, internal IP kolayca cikarilabilir.
- **Deploy'da duzeltilecek:** EVET — Build komutlarina eklenmeli:
```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols --dart-define=PROD=true
flutter build ios --release --obfuscate --split-debug-info=build/symbols --dart-define=PROD=true
```

#### O2 — Kullanici Verisi Sifrelenmemis SQLite'da

- **Dosya:** `lib/db/database_helper.dart` satir 86-93
- **Risk:** `stoksay.db` sifrelenmemis. Root/jailbreak cihazda kullanici profili, yetkiler, is verileri okunabilir.
- **Cozum:** `sqflite` yerine `sqflite_sqlcipher` paketi ile sifrelenmis SQLite.
- **Deploy'da duzeltilecek:** HAYIR — Paket degisikligi ve migrasyon gerektirir. Envanter verisi cok hassas degil, dusuk oncelik.

#### O3 — Hardcoded Internal IP Adresi

- **Dosya:** `lib/config/api_config.dart` satir 7
- **Risk:** `http://172.22.23.243:3001` internal ag IP'si binary'de kalir. Ag topolojisi sizintisi.
- **Deploy'da duzeltilecek:** EVET — Dev URL'i `String.fromEnvironment` ile disaridan alinmali veya release build'de sadece prod URL kalacak sekilde duzenlenmeli.

#### O4 — AndroidManifest allowBackup Eksik

- **Dosya:** `android/app/src/main/AndroidManifest.xml` satir 3
- **Risk:** Varsayilan olarak `allowBackup=true`. ADB ile uygulama verileri (SQLite DB dahil) yedeklenip okunabilir.
- **Deploy'da duzeltilecek:** EVET — `<application>` etiketine eklenmeli:
```xml
<application android:allowBackup="false" ...>
```

#### O5 — Login Input Dogrulama Eksik

- **Dosya:** `lib/screens/login_screen.dart` satir 44-49
- **Risk:** Email format kontrolu ve sifre minimum uzunluk kontrolu yok. Sadece bos alan kontrolu yapiliyor.
- **Gercek etki:** DUSUK — Backend dogrulama yapiyor, client-side sadece UX.
- **Deploy'da duzeltilecek:** HAYIR — Iyilestirme olarak planlanabilir.

#### O6 — Token Memory'de Static Plaintext

- **Dosya:** `lib/services/storage_service.dart` satir 12
- **Risk:** `static String? _cachedToken` — token memory dump ile okunabilir (root cihaz).
- **Gercek etki:** COK DUSUK — Root cihaz gerektirir, FlutterSecureStorage zaten birincil depolama.
- **Deploy'da duzeltilecek:** HAYIR — Performans gerekliligi, kabul edilebilir risk.

#### O7 — Genel Exception Hata Kaybi

- **Dosya:** `lib/services/api_service.dart`
- **Risk:** API hatalari genel `Exception` firlatiliyor, hata detayi (status code, mesaj) kayboluyor.
- **Deploy'da duzeltilecek:** EVET — Ozel exception sinifi olusturulacak.

#### O8 — Offline Handling Yok

- **Dosyalar:** Tum screen'ler
- **Risk:** Internet baglantisi yoksa kullaniciya bilgi verilmiyor. Ekran donuyor.
- **Deploy'da duzeltilecek:** EVET — Connectivity check + kullanici bildirimi eklenecek.

#### O9 — TextEditingController Dispose Edilmiyor

- **Dosya:** `lib/screens/sayim_detay_screen.dart`
- **Risk:** Controller dispose edilmediginde memory leak olusur.
- **Deploy'da duzeltilecek:** EVET — dispose() eklenmeli.

---

### DUSUK

#### D1 — debugPrint ile Hata Detaylari

- **Dosya:** `lib/screens/toplanmis_sayimlar_screen.dart` satir 65
- **Risk:** `debugPrint('toplanmis fetch error: $e')` — hata nesnesi loglanabilir.
- **Gercek etki:** YOK — `debugPrint` release modda Flutter tarafindan otomatik strip edilir.
- **Deploy'da duzeltilecek:** HAYIR — Release'de zaten calismaz.

#### D2 — Screenshot / Screen Recording Korumasi Yok

- **Risk:** Hassas veriler ekran goruntusu ile paylasilabilir.
- **Gercek etki:** DUSUK — Envanter verileri icin dusuk risk.
- **Deploy'da duzeltilecek:** HAYIR — Gerektiginde eklenebilir.

---

## Deploy Oncesi Kontrol Listesi

### ZORUNLU (Deploy engelleyici)

- [ ] **iOS ATS duzelt** — `Info.plist`'ten `NSAllowsArbitraryLoads` kaldir, domain exception ekle (Y1)
- [ ] **Release signing key** — Android icin gercek keystore olustur ve `build.gradle.kts`'te ayarla (Y4)
- [ ] **Build komutu** — `--dart-define=PROD=true` parametresi SART (Y3)
- [ ] **api_config.dart** — `_prodUrl` degerini gercek domain ile degistir (Y3)

### ONERILEN (Deploy sonrasi da yapilabilir)

- [ ] **Obfuscation ekle** — `--obfuscate --split-debug-info=build/symbols` (O1)
- [ ] **allowBackup="false"** — AndroidManifest.xml'e ekle (O4)
- [ ] **Internal IP temizle** — Dev URL'i kaynak koddan cikar veya env variable yap (O3)

### GELECEK SPRINT

- [ ] SSL certificate pinning (Y2)
- [ ] SQLite sifreleme — sqflite_sqlcipher (O2)
- [ ] Login form dogrulama (O5)

---

## Uretim Build Komutlari

```bash
# Android
flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/symbols \
  --dart-define=PROD=true

# iOS
flutter build ios --release \
  --obfuscate \
  --split-debug-info=build/symbols \
  --dart-define=PROD=true
```

---

## Test Sonuclari (2026-03-15)

| Kategori | Sonuc |
|----------|-------|
| Token depolama (FlutterSecureStorage) | PASS |
| Prod/Dev URL ayrimi | PASS |
| Auth guard (GoRouter redirect) | PASS |
| Logout temizlik (DB + token) | PASS |
| Hardcoded secret taramasi | PASS — Bulunamadi |
| Hassas veri log taramasi | PASS — Token/sifre loglanmiyor |
| Deep link saldiri yuzeyi | PASS — Tanimli degil |
| Dependency guncelligi | PASS — Tum paketler guncel |
