import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/isletme.dart';
import '../services/depo_service.dart';
import '../services/urun_service.dart';
import '../services/sayim_service.dart';
import 'database_helper.dart';

class SyncService {
  static Future<void> tamSenkronizasyon(List<Isletme> isletmeler) async {
    final db = await DatabaseHelper.database;

    for (final isletme in isletmeler) {
      // Depolar
      try {
        final depolar = await DepoService.listele(isletme.id);
        await db.delete('depolar', where: 'isletme_id = ?', whereArgs: [isletme.id]);
        for (final d in depolar) {
          await db.insert('depolar', {
            'id': d['id'],
            'ad': d['ad'],
            'konum': d['konum'],
            'isletme_id': isletme.id,
            'aktif': d['aktif'] == true ? 1 : 0,
            'son_guncelleme': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } catch (_) {}

      // Urunler
      try {
        final liste = await UrunService.listele(isletme.id, sayfa: 1, limit: 10000);
        await db.delete('urunler', where: 'isletme_id = ?', whereArgs: [isletme.id]);
        for (final u in liste) {
          await db.insert('urunler', {
            'id': u['id'],
            'urun_kodu': u['urun_kodu'],
            'urun_adi': u['urun_adi'],
            'isim_2': u['isim_2'],
            'birim': u['birim'],
            'kategori': u['kategori'],
            'barkodlar': jsonEncode(u['barkodlar'] ?? []),
            'isletme_id': isletme.id,
            'aktif': u['aktif'] == true ? 1 : 0,
            'son_guncelleme': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } catch (_) {}

      // Sayimlar
      try {
        final sayimlar = await SayimService.listele(isletme.id);
        await db.delete('sayimlar', where: 'isletme_id = ?', whereArgs: [isletme.id]);
        for (final s in sayimlar) {
          await db.insert('sayimlar', {
            'id': s['id'],
            'ad': s['ad'],
            'tarih': s['tarih'],
            'durum': s['durum'],
            'isletme_id': isletme.id,
            'depo_id': s['depo_id'],
            'kullanici_id': s['kullanici_id'],
            'kisiler': jsonEncode(s['kisiler'] ?? []),
            'notlar': s['notlar'],
            'son_guncelleme': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);

          // Kalemler
          try {
            final kalemler = await SayimService.kalemListele(s['id']);
            for (final k in kalemler) {
              await db.insert('sayim_kalemleri', {
                'id': k['id'],
                'sayim_id': s['id'],
                'urun_id': k['urun_id'],
                'miktar': k['miktar'],
                'birim': k['birim'],
                'notlar': k['notlar'],
                'son_guncelleme': DateTime.now().toIso8601String(),
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          } catch (_) {}
        }
      } catch (_) {}
    }
  }

  static Future<void> kuyruguGonder() async {
    final db = await DatabaseHelper.database;
    final bekleyenler = await db.query(
      'sync_queue',
      where: 'durum = ?',
      whereArgs: ['bekliyor'],
      orderBy: 'id ASC',
    );

    for (final item in bekleyenler) {
      final id = item['id'] as int;
      final tablo = item['tablo'] as String;
      final islem = item['islem'] as String;
      final veri = jsonDecode(item['veri'] as String);

      await db.update('sync_queue', {'durum': 'gonderiliyor'}, where: 'id = ?', whereArgs: [id]);

      try {
        switch (tablo) {
          case 'depolar':
            if (islem == 'ekle') {
              final result = await DepoService.ekle(veri['isletme_id'], veri['ad'], konum: veri['konum']);
              final tempId = veri['_temp_id'];
              if (tempId != null && result['id'] != null) {
                await db.update('depolar', {'id': result['id']}, where: 'id = ?', whereArgs: [tempId]);
              }
            }
            break;
          case 'sayimlar':
            if (islem == 'ekle') {
              final result = await SayimService.olustur(veri);
              final tempId = veri['_temp_id'];
              if (tempId != null && result['id'] != null) {
                await db.update('sayimlar', {'id': result['id']}, where: 'id = ?', whereArgs: [tempId]);
                await db.update('sayim_kalemleri', {'sayim_id': result['id']}, where: 'sayim_id = ?', whereArgs: [tempId]);
              }
            } else if (islem == 'tamamla') {
              await SayimService.tamamla(veri['id']);
            }
            break;
          case 'sayim_kalemleri':
            if (islem == 'ekle') {
              final result = await SayimService.kalemEkle(veri['sayim_id'], veri);
              final tempId = veri['_temp_id'];
              if (tempId != null && result['id'] != null) {
                await db.update('sayim_kalemleri', {'id': result['id']}, where: 'id = ?', whereArgs: [tempId]);
              }
            } else if (islem == 'guncelle') {
              await SayimService.kalemGuncelle(veri['sayim_id'], veri['id'], veri);
            } else if (islem == 'sil') {
              await SayimService.kalemSil(veri['sayim_id'], veri['id']);
            }
            break;
          case 'urunler':
            if (islem == 'ekle') {
              final result = await UrunService.ekle(veri);
              final tempId = veri['_temp_id'];
              if (tempId != null && result['id'] != null) {
                await db.update('urunler', {'id': result['id']}, where: 'id = ?', whereArgs: [tempId]);
              }
            }
            break;
        }
        await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
      } catch (_) {
        await db.update('sync_queue', {'durum': 'hata'}, where: 'id = ?', whereArgs: [id]);
      }
    }
  }

  static Future<void> kuyruguEkle(String tablo, String islem, Map<String, dynamic> veri) async {
    final db = await DatabaseHelper.database;
    await db.insert('sync_queue', {
      'tablo': tablo,
      'islem': islem,
      'veri': jsonEncode(veri),
      'olusturma': DateTime.now().toIso8601String(),
      'durum': 'bekliyor',
    });
  }

  static Future<int> bekleyenSayisi() async {
    final db = await DatabaseHelper.database;
    final result = await db.rawQuery("SELECT COUNT(*) as c FROM sync_queue WHERE durum IN ('bekliyor','hata')");
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
