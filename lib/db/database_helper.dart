import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'stoksay.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE isletmeler (
            id INTEGER PRIMARY KEY,
            ad TEXT NOT NULL,
            kod TEXT,
            aktif INTEGER DEFAULT 1,
            son_guncelleme TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE depolar (
            id INTEGER PRIMARY KEY,
            ad TEXT NOT NULL,
            konum TEXT,
            isletme_id INTEGER,
            aktif INTEGER DEFAULT 1,
            son_guncelleme TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_depolar_isletme ON depolar(isletme_id)');

        await db.execute('''
          CREATE TABLE urunler (
            id INTEGER PRIMARY KEY,
            urun_kodu TEXT,
            urun_adi TEXT NOT NULL,
            isim_2 TEXT,
            birim TEXT,
            kategori TEXT,
            barkodlar TEXT,
            isletme_id INTEGER,
            aktif INTEGER DEFAULT 1,
            son_guncelleme TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_urunler_isletme ON urunler(isletme_id)');

        await db.execute('''
          CREATE TABLE sayimlar (
            id INTEGER PRIMARY KEY,
            ad TEXT NOT NULL,
            tarih TEXT,
            durum TEXT DEFAULT 'devam',
            isletme_id INTEGER,
            depo_id INTEGER,
            kullanici_id INTEGER,
            kisiler TEXT,
            notlar TEXT,
            son_guncelleme TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_sayimlar_isletme ON sayimlar(isletme_id)');

        await db.execute('''
          CREATE TABLE sayim_kalemleri (
            id INTEGER PRIMARY KEY,
            sayim_id INTEGER,
            urun_id INTEGER,
            miktar REAL,
            birim TEXT,
            notlar TEXT,
            son_guncelleme TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_kalemler_sayim ON sayim_kalemleri(sayim_id)');

        await db.execute('''
          CREATE TABLE kullanici_cache (
            id INTEGER PRIMARY KEY,
            kullanici TEXT,
            yetkiler_map TEXT,
            son_guncelleme TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tablo TEXT NOT NULL,
            islem TEXT NOT NULL,
            veri TEXT NOT NULL,
            olusturma TEXT NOT NULL,
            durum TEXT DEFAULT 'bekliyor'
          )
        ''');
        await db.execute('CREATE INDEX idx_sync_durum ON sync_queue(durum)');
      },
    );
  }

  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('isletmeler');
    await db.delete('depolar');
    await db.delete('urunler');
    await db.delete('sayimlar');
    await db.delete('sayim_kalemleri');
    await db.delete('kullanici_cache');
    await db.delete('sync_queue');
  }
}
