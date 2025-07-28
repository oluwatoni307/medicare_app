import 'package:sqflite/sqflite.dart';

import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;
  DBHelper._internal();

  factory DBHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      // Web: Initialize sqflite_common_ffi_web
      return await openDatabase('medicare.db', version: 1, onCreate: _createTables);
    } else {
      // Mobile: Use original sqflite path
      String path = join(await getDatabasesPath(), 'medicare.db');
      return await openDatabase(path, version: 1, onCreate: _createTables);
    }
  }

  Future<void> _createTables(Database db, int version) async {
    // -- Users table
    await db.execute('''
      CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          email TEXT UNIQUE,
          created_at TEXT NOT NULL
      )
    ''');

    // -- Medicines table
    await db.execute('''
      CREATE TABLE medicines (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          dosage TEXT NOT NULL,
          user_id INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // -- Schedules table
    await db.execute('''
      CREATE TABLE schedules (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          medicine_id INTEGER NOT NULL,
          time TEXT NOT NULL,
          start_date TEXT NOT NULL,
          end_date TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (medicine_id) REFERENCES schedules(id) ON DELETE CASCADE
      )
    ''');

    // -- Logs table
    await db.execute('''
      CREATE TABLE logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          schedule_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          status TEXT NOT NULL CHECK (status IN ('taken', 'missed')),
          created_at TEXT NOT NULL,
          FOREIGN KEY (schedule_id) REFERENCES schedules(id) ON DELETE CASCADE
      )
    ''');
  }

  // User CRUD operations
  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert('users', user);
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await database;
    return await db.query('users');
  }

  Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await database;
    final result = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateUser(int id, Map<String, dynamic> user) async {
    final db = await database;
    return await db.update('users', user, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // Medicine CRUD operations
  Future<int> insertMedicine(Map<String, dynamic> medicine) async {
    final db = await database;
    return await db.insert('medicines', medicine);
  }

  Future<List<Map<String, dynamic>>> getMedicines(int userId) async {
    final db = await database;
    return await db.query(
      'medicines',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<Map<String, dynamic>?> getMedicineById(int id) async {
    final db = await database;
    final result = await db.query('medicines', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateMedicine(int id, Map<String, dynamic> medicine) async {
    final db = await database;
    return await db.update('medicines', medicine, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteMedicine(int id) async {
    final db = await database;
    return await db.delete('medicines', where: 'id = ?', whereArgs: [id]);
  }

  // Schedule CRUD operations
  Future<int> insertSchedule(Map<String, dynamic> schedule) async {
    final db = await database;
    return await db.insert('schedules', schedule);
  }

  Future<List<Map<String, dynamic>>> getSchedules(int medicineId) async {
    final db = await database;
    return await db.query('schedules', where: 'medicine_id = ?', whereArgs: [medicineId]);
  }

  Future<List<Map<String, dynamic>>> getAllSchedules() async {
    final db = await database;
    return await db.query('schedules');
  }

  Future<Map<String, dynamic>?> getScheduleById(int id) async {
    final db = await database;
    final result = await db.query('schedules', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateSchedule(int id, Map<String, dynamic> schedule) async {
    final db = await database;
    return await db.update('schedules', schedule, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteSchedule(int id) async {
    final db = await database;
    return await db.delete('schedules', where: 'id = ?', whereArgs: [id]);
  }

  // Log CRUD operations
  Future<int> insertLog(Map<String, dynamic> log) async {
    final db = await database;
    return await db.insert('logs', log);
  }

  Future<List<Map<String, dynamic>>> getLogs(String date) async {
    final db = await database;
    return await db.query('logs', where: 'date = ?', whereArgs: [date]);
  }

  Future<List<Map<String, dynamic>>> getLogsBySchedule(int scheduleId) async {
    final db = await database;
    return await db.query('logs', where: 'schedule_id = ?', whereArgs: [scheduleId]);
  }

  Future<Map<String, dynamic>?> getLogById(int id) async {
    final db = await database;
    final result = await db.query('logs', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateLog(int id, Map<String, dynamic> log) async {
    final db = await database;
    return await db.update('logs', log, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteLog(int id) async {
    final db = await database;
    return await db.delete('logs', where: 'id = ?', whereArgs: [id]);
  }

  // Utility methods
  Future<void> testDatabase() async {
    final db = await database;
    print('Database initialized successfully at ${db.path}');
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}