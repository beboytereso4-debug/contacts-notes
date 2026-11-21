import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/contact.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _table = 'contacts';
  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'contacts_book.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL,
            email TEXT,
            is_favorite INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            photo_path TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $_table ADD COLUMN created_at INTEGER');
          // Legacy records receive a stable migration timestamp.
          await db.execute(
            'UPDATE $_table SET created_at = ? WHERE created_at IS NULL',
            [DateTime.now().millisecondsSinceEpoch],
          );
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE $_table ADD COLUMN photo_path TEXT');
        }
      },
    );
  }

  Future<int> insert(Contact contact) async {
    final db = await database;
    final values = contact.toMap()..remove('id');
    values['created_at'] ??= DateTime.now().millisecondsSinceEpoch;
    return db.insert(_table, values);
  }

  Future<List<Contact>> getContacts({
    String query = '',
    String sortBy = 'name',
    bool descending = false,
  }) async {
    final db = await database;
    final trimmed = query.trim();
    final sortColumn = sortBy == 'date' ? 'created_at' : 'name COLLATE NOCASE';
    final direction = descending ? 'DESC' : 'ASC';
    final rows = await db.query(
      _table,
      where: trimmed.isEmpty ? null : 'name LIKE ? OR phone LIKE ? OR email LIKE ?',
      whereArgs: trimmed.isEmpty ? null : ['%$trimmed%', '%$trimmed%', '%$trimmed%'],
      orderBy: 'is_favorite DESC, $sortColumn $direction, name COLLATE NOCASE ASC',
    );
    return rows.map(Contact.fromMap).toList();
  }

  Future<int> update(Contact contact) async {
    final db = await database;
    final values = contact.toMap()..remove('id');
    values.remove('created_at'); // Editing never changes the original date.
    return db.update(_table, values, where: 'id = ?', whereArgs: [contact.id]);
  }

  Future<int> delete(int id) async {
    final db = await database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
