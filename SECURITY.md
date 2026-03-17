# StokSay Mobile - Guvenlik

## Kimlik Dogrulama
- JWT token tabanli kimlik dogrulama
- Token `SharedPreferences`'ta saklanir
- Her API isteginde `Authorization: Bearer <token>` header'i eklenir
- Token suresi doldugunda otomatik logout

## Veri Guvenligi

### Yerel Veri (SQLite)
- Tum offline veriler cihaz uzerindeki SQLite veritabaninda saklanir
- Veritabani Flutter'in uygulama dizininde tutulur (sandbox)
- Kullanici cikarisinda token temizlenir

### Sync Queue
- Senkronizasyon kuyrugu `sync_queue` tablosunda tutulur
- Her kayit tablo adi, islem tipi ve JSON veri icerir
- Basarili gonderilen kayitlar kuyruktan silinir
- Hata durumunda kayit `hata` durumuna gecer

### API Iletisimi
- HTTPS uzerinden sifrelenmis iletisim (production)
- Dio interceptor ile token yonetimi
- 401 hatalarinda otomatik logout

## Hassas Veri Yonetimi
- Kullanici parolasi cihazda saklanmaz
- JWT token disinda kimlik bilgisi tutulmaz
- Offline veriler yalnizca kullanicinin isletme verilerini icerir

## Offline Mod Guvenligi
- Offline modda tum veriler yerel SQLite'ta islenenir
- Sync queue yalnizca kullanicinin kendi islemlerini icerir
- Temp ID sistemi UUID cakismasi olusturmaz
- Senkronizasyonda sunucu tarafli dogrulama yapilir

## Bilinen Sinirlamalar
- SQLite veritabani sifrelenmemistir (cihaz guvenligi ile korunur)
- Root/jailbreak cihazlarda veri erisimi mumkundur
- Offline moddayken sunucu tarafli yetkilendirme atlanir (sync sirasinda kontrol edilir)
