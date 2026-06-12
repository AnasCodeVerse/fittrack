import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  // Bump this whenever schema or seeded data changes.
  static const int _dbVersion = 3;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('fitness.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, filePath);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  // ---------- SCHEMA ----------
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sleep_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        sleep_time TEXT NOT NULL,
        wake_time TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        muscle_group TEXT NOT NULL,
        is_custom INTEGER DEFAULT 0
      )
    ''');

    // workout_type: 'gym' | 'home' | 'skipping' | 'emom' | 'plank'
    await db.execute('''
      CREATE TABLE workout_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        muscle_groups TEXT,
        note TEXT,
        workout_type TEXT NOT NULL DEFAULT 'gym'
      )
    ''');

    // duration_seconds is used for timed exercises (plank, skipping). 0 for normal sets.
    await db.execute('''
      CREATE TABLE workout_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        exercise_id INTEGER NOT NULL,
        set_number INTEGER NOT NULL,
        reps INTEGER NOT NULL,
        weight REAL NOT NULL,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(session_id) REFERENCES workout_sessions(id) ON DELETE CASCADE,
        FOREIGN KEY(exercise_id) REFERENCES exercises(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        title TEXT,
        content TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE body_weight (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        weight REAL NOT NULL,
        photo_path TEXT
      )
    ''');

    // EMOM templates. config is a JSON list of {exercise_id, reps}.
    await db.execute('''
      CREATE TABLE emom_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        total_minutes INTEGER NOT NULL,
        config TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await _ensureExercises(db, _gymExercises);
    await _ensureExercises(db, _homeExercises);
  }

  // ---------- MIGRATIONS ----------
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 -> v2: add workout_type, duration_seconds, seed Legs
    if (oldVersion < 2) {
      await db.execute(
          "ALTER TABLE workout_sessions ADD COLUMN workout_type TEXT NOT NULL DEFAULT 'gym'");
      await db.execute(
          "ALTER TABLE workout_sets ADD COLUMN duration_seconds INTEGER NOT NULL DEFAULT 0");
      await _ensureExercises(db, _gymExercises);
    }
    // v2 -> v3: seed home exercises, create emom_templates table
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS emom_templates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          total_minutes INTEGER NOT NULL,
          config TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      await _ensureExercises(db, _homeExercises);
    }
  }

  // ---------- SEED DATA ----------
  static const Map<String, List<String>> _gymExercises = {
    'Chest': [
      'Incline Bench Press',
      'Incline Dumbbell Press',
      'Pec Dec Fly',
      'Cable Fly',
      'Pushups',
    ],
    'Back': [
      'Lat Pulldown',
      'Seated Rows',
      'Lat Pull-Over',
      'Pull Ups',
      'Machine Rows',
    ],
    'Triceps': [
      'Push Down',
      'Overhead Extension',
      'Skull Crushers',
      'Single Arm Push Down',
    ],
    'Biceps': [
      'EZ Bar Curls',
      'Hammer Curls',
      'Lying Bicep Curls',
    ],
    'Shoulders': [
      'Shoulder Dumbbell Press',
      'Overhead Press',
      'Cable Lateral Raises',
      'Face Pulls',
      'Front Raises',
    ],
    'Legs': [
      'Barbell Squat',
      'Leg Press',
      'Romanian Deadlift',
      'Leg Curls',
      'Leg Extensions',
      'Lunges',
      'Calf Raises',
      'Hip Thrusts',
    ],
  };

  // Home exercises. Each category is its own muscle_group so the existing
  // getExercisesByGroup() flow works without changes.
  static const Map<String, List<String>> _homeExercises = {
    'Pushups': [
      'Standard Pushups',
      'Incline Pushups',
      'Decline Pushups',
      'Diamond Pushups',
      'Wide Pushups',
    ],
    'Pullups': [
      'Pull Ups',
      'Chin Ups',
      'Wide Grip Pullups',
      'Neutral Grip Pullups',
    ],
    'Squats': [
      'Bodyweight Squat',
      'Jump Squats',
      'Pistol Squats',
      'Sumo Squats',
      'Bulgarian Split Squat',
    ],
    'Abs': [
      'Crunches',
      'Sit Ups',
      'Leg Raises',
      'Russian Twists',
      'Mountain Climbers',
      'Bicycle Crunches',
      'V-Ups',
    ],
    'Planks': [
      'Plank',
      'Side Plank',
      'Plank Shoulder Taps',
    ],
    'Rope Skipping': [
      'Rope Skipping',
    ],
  };

  Future<void> _ensureExercises(
      Database db, Map<String, List<String>> exercises) async {
    for (final group in exercises.keys) {
      for (final ex in exercises[group]!) {
        final existing = await db.query(
          'exercises',
          where: 'name = ? AND muscle_group = ?',
          whereArgs: [ex, group],
        );
        if (existing.isEmpty) {
          await db.insert('exercises', {
            'name': ex,
            'muscle_group': group,
            'is_custom': 0,
          });
        }
      }
    }
  }

  // -- SLEEP --
  Future<int> insertSleep(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('sleep_entries', row);
  }

  Future<List<Map<String, dynamic>>> getAllSleep() async {
    final db = await instance.database;
    return await db.query('sleep_entries', orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> getSleepInRange(
      DateTime start, DateTime end) async {
    final db = await instance.database;
    return await db.query(
      'sleep_entries',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date ASC',
    );
  }

  Future<int> deleteSleep(int id) async {
    final db = await instance.database;
    return await db.delete('sleep_entries', where: 'id = ?', whereArgs: [id]);
  }

  // -- EXERCISES --
  Future<List<Map<String, dynamic>>> getExercisesByGroup(String group) async {
    final db = await instance.database;
    return await db.query('exercises',
        where: 'muscle_group = ?', whereArgs: [group], orderBy: 'name ASC');
  }

  Future<Map<String, dynamic>?> getExerciseByName(
      String name, String group) async {
    final db = await instance.database;
    final r = await db.query('exercises',
        where: 'name = ? AND muscle_group = ?',
        whereArgs: [name, group],
        limit: 1);
    return r.isEmpty ? null : r.first;
  }

  Future<List<Map<String, dynamic>>> getAllExercises() async {
    final db = await instance.database;
    return await db.query('exercises', orderBy: 'muscle_group ASC, name ASC');
  }

  Future<int> insertExercise(String name, String group) async {
    final db = await instance.database;
    return await db.insert('exercises', {
      'name': name,
      'muscle_group': group,
      'is_custom': 1,
    });
  }

  Future<int> deleteExercise(int id) async {
    final db = await instance.database;
    return await db
        .delete('exercises', where: 'id = ? AND is_custom = 1', whereArgs: [id]);
  }

  // -- WORKOUTS --
  Future<int> insertSession(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('workout_sessions', row);
  }

  Future<int> insertSet(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('workout_sets', row);
  }

  Future<List<Map<String, dynamic>>> getAllSessions() async {
    final db = await instance.database;
    return await db.query('workout_sessions', orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> getSetsForSession(int sessionId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT ws.*, e.name as exercise_name, e.muscle_group
      FROM workout_sets ws
      JOIN exercises e ON ws.exercise_id = e.id
      WHERE ws.session_id = ?
      ORDER BY e.name, ws.set_number
    ''', [sessionId]);
  }

  Future<int> deleteSession(int id) async {
    final db = await instance.database;
    await db.delete('workout_sets', where: 'session_id = ?', whereArgs: [id]);
    return await db.delete('workout_sessions', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getMaxWeightForExercise(int exerciseId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT ws.weight, ws.reps, wsess.date
      FROM workout_sets ws
      JOIN workout_sessions wsess ON ws.session_id = wsess.id
      WHERE ws.exercise_id = ?
      ORDER BY ws.weight DESC, ws.reps DESC
      LIMIT 1
    ''', [exerciseId]);
    if (result.isEmpty) return null;
    return result.first;
  }

  Future<List<Map<String, dynamic>>> getProgressForExercise(
      int exerciseId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT MAX(ws.weight) as max_weight, wsess.date
      FROM workout_sets ws
      JOIN workout_sessions wsess ON ws.session_id = wsess.id
      WHERE ws.exercise_id = ?
      GROUP BY wsess.date
      ORDER BY wsess.date ASC
    ''', [exerciseId]);
  }

  // -- EMOM TEMPLATES --
  Future<int> insertEmomTemplate({
    required String name,
    required int totalMinutes,
    required List<Map<String, dynamic>> config,
  }) async {
    final db = await instance.database;
    return await db.insert('emom_templates', {
      'name': name,
      'total_minutes': totalMinutes,
      'config': jsonEncode(config),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAllEmomTemplates() async {
    final db = await instance.database;
    return await db.query('emom_templates', orderBy: 'created_at DESC');
  }

  Future<int> deleteEmomTemplate(int id) async {
    final db = await instance.database;
    return await db.delete('emom_templates', where: 'id = ?', whereArgs: [id]);
  }

  // -- NOTES --
  Future<int> insertNote(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('notes', row);
  }

  Future<List<Map<String, dynamic>>> getAllNotes() async {
    final db = await instance.database;
    return await db.query('notes', orderBy: 'date DESC');
  }

  Future<int> updateNote(int id, Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.update('notes', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteNote(int id) async {
    final db = await instance.database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // -- BODY WEIGHT --
  Future<int> insertBodyWeight(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('body_weight', row);
  }

  Future<List<Map<String, dynamic>>> getAllBodyWeight() async {
    final db = await instance.database;
    return await db.query('body_weight', orderBy: 'date DESC');
  }

  Future<int> deleteBodyWeight(int id) async {
    final db = await instance.database;
    return await db.delete('body_weight', where: 'id = ?', whereArgs: [id]);
  }

  // -- EXPORT/IMPORT --
  Future<Map<String, dynamic>> exportAllData() async {
    final db = await instance.database;
    return {
      'schema_version': _dbVersion,
      'sleep_entries': await db.query('sleep_entries'),
      'exercises': await db.query('exercises'),
      'workout_sessions': await db.query('workout_sessions'),
      'workout_sets': await db.query('workout_sets'),
      'emom_templates': await db.query('emom_templates'),
      'notes': await db.query('notes'),
      'body_weight': await db.query('body_weight'),
      'export_date': DateTime.now().toIso8601String(),
    };
  }

  Future<void> importAllData(Map<String, dynamic> data) async {
    final db = await instance.database;
    final batch = db.batch();
    batch.delete('workout_sets');
    batch.delete('workout_sessions');
    batch.delete('sleep_entries');
    batch.delete('notes');
    batch.delete('body_weight');
    batch.delete('exercises');
    batch.delete('emom_templates');
    await batch.commit();

    final batch2 = db.batch();
    for (final row in (data['exercises'] as List)) {
      batch2.insert('exercises', Map<String, dynamic>.from(row));
    }
    for (final row in (data['sleep_entries'] as List)) {
      batch2.insert('sleep_entries', Map<String, dynamic>.from(row));
    }
    for (final row in (data['workout_sessions'] as List)) {
      final map = Map<String, dynamic>.from(row);
      map['workout_type'] = map['workout_type'] ?? 'gym';
      batch2.insert('workout_sessions', map);
    }
    for (final row in (data['workout_sets'] as List)) {
      final map = Map<String, dynamic>.from(row);
      map['duration_seconds'] = map['duration_seconds'] ?? 0;
      batch2.insert('workout_sets', map);
    }
    if (data['emom_templates'] != null) {
      for (final row in (data['emom_templates'] as List)) {
        batch2.insert('emom_templates', Map<String, dynamic>.from(row));
      }
    }
    for (final row in (data['notes'] as List)) {
      batch2.insert('notes', Map<String, dynamic>.from(row));
    }
    for (final row in (data['body_weight'] as List)) {
      batch2.insert('body_weight', Map<String, dynamic>.from(row));
    }
    await batch2.commit();
  }
}
