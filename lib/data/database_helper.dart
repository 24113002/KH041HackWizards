import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/patient_model.dart';
import '../models/screening_session_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('swasthai_health.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Enable FFI on desktop platforms (Windows, Linux, macOS) or pure Dart VM
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        path = join(appDocDir.path, 'SwasthaiData', filePath);
        // Ensure directory exists
        final dir = Directory(join(appDocDir.path, 'SwasthaiData'));
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      } catch (_) {
        path = inMemoryDatabasePath;
      }
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE patients (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        gender TEXT NOT NULL,
        height_cm REAL NOT NULL,
        weight_kg REAL NOT NULL,
        phone TEXT,
        medical_history TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE screenings (
        id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        heart_rate INTEGER,
        spo2 INTEGER,
        fev1 REAL,
        fvc REAL,
        fev1_fvc_ratio REAL,
        pef_lpm REAL,
        cough_count INTEGER,
        symptom_score INTEGER,
        risk_level TEXT,
        risk_score INTEGER,
        clinical_pattern TEXT,
        clinical_notes TEXT,
        full_payload_json TEXT,
        FOREIGN KEY (patient_id) REFERENCES patients (id) ON DELETE CASCADE
      )
    ''');
  }

  // --- Patient Operations ---

  Future<int> insertPatient(Patient patient) async {
    final db = await database;
    return await db.insert(
      'patients',
      patient.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updatePatient(Patient patient) async {
    final db = await database;
    return await db.update(
      'patients',
      patient.toMap(),
      where: 'id = ?',
      whereArgs: [patient.id],
    );
  }

  Future<int> deletePatient(String id) async {
    final db = await database;
    return await db.delete('patients', where: 'id = ?', whereArgs: [id]);
  }

  Future<Patient?> getPatient(String id) async {
    final db = await database;
    final maps = await db.query('patients', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Patient.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Patient>> getAllPatients() async {
    final db = await database;
    final maps = await db.query('patients', orderBy: 'created_at DESC');
    return maps.map((m) => Patient.fromMap(m)).toList();
  }

  Future<List<Patient>> searchPatients(String query) async {
    final db = await database;
    final maps = await db.query(
      'patients',
      where: 'name LIKE ? OR phone LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Patient.fromMap(m)).toList();
  }

  // --- Screening Operations ---

  Future<int> insertScreening(ScreeningSession session) async {
    final db = await database;
    return await db.insert(
      'screenings',
      session.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteScreening(String id) async {
    final db = await database;
    return await db.delete('screenings', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ScreeningSession>> getScreeningsForPatient(String patientId) async {
    final db = await database;
    final patient = await getPatient(patientId);
    final maps = await db.query(
      'screenings',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => ScreeningSession.fromDbMap(m, attachedPatient: patient)).toList();
  }

  Future<List<ScreeningSession>> getAllScreenings({int limit = 50}) async {
    final db = await database;
    final maps = await db.query('screenings', orderBy: 'timestamp DESC', limit: limit);
    final patients = await getAllPatients();
    final patientMap = {for (var p in patients) p.id: p};

    return maps.map((m) {
      final pId = m['patient_id'] as String;
      return ScreeningSession.fromDbMap(m, attachedPatient: patientMap[pId]);
    }).toList();
  }

  Future<Map<String, int>> getDashboardStats() async {
    final db = await database;
    final totalPatients = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM patients'),
        ) ??
        0;
    final totalScreenings = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM screenings'),
        ) ??
        0;
    final lowRisk = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM screenings WHERE risk_level = ?', ['low']),
        ) ??
        0;
    final modRisk = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM screenings WHERE risk_level = ?', ['moderate']),
        ) ??
        0;
    final highRisk = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM screenings WHERE risk_level = ?', ['high']),
        ) ??
        0;
    final critRisk = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM screenings WHERE risk_level = ?', ['critical']),
        ) ??
        0;

    return {
      'total_patients': totalPatients,
      'total_screenings': totalScreenings,
      'low_risk': lowRisk,
      'moderate_risk': modRisk,
      'high_risk': highRisk,
      'critical_risk': critRisk,
    };
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
