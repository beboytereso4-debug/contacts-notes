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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL,
            email TEXT,
            is_favorite INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  // CREATE
  Future<int> insert(Contact contact) async {
    final db = await database;
    return db.insert(_table, contact.toMap()..remove('id'));
  }

  // READ (favorites first, then alphabetical; optional search)
  Future<List<Contact>> getContacts({String query = ''}) async {
    final db = await database;
    final trimmed = query.trim();
    final rows = await db.query(
      _table,
      where: trimmed.isEmpty ? null : 'name LIKE ? OR phone LIKE ? OR email LIKE ?',
      whereArgs: trimmed.isEmpty ? null : ['%$trimmed%', '%$trimmed%', '%$trimmed%'],
      orderBy: 'is_favorite DESC, name COLLATE NOCASE ASC',
    );
    return rows.map(Contact.fromMap).toList();
  }

  // UPDATE
  Future<int> update(Contact contact) async {
    final db = await database;
    return db.update(
      _table,
      contact.toMap(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  // DELETE
  Future<int> delete(int id) async {
    final db = await database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
