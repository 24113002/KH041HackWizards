import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:universal_io/io.dart';
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
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (kIsWeb) {
      path = filePath;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        path = join(appDocDir.path, 'SwasthaiData', filePath);
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

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: _createDB,
        onUpgrade: _onUpgradeDB,
        onOpen: (db) async {
          await _ensureColumns(db);
        },
      ),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS patients (
        id TEXT PRIMARY KEY,
        backend_id INTEGER,
        full_name TEXT NOT NULL,
        name TEXT,
        age INTEGER NOT NULL,
        gender TEXT NOT NULL,
        village TEXT,
        occupation TEXT,
        smoking_status TEXT,
        height_cm REAL,
        weight_kg REAL,
        phone TEXT,
        medical_history TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS screenings (
        id TEXT PRIMARY KEY,
        backend_id INTEGER,
        patient_id TEXT NOT NULL,
        patient_backend_id INTEGER,
        started_at TEXT NOT NULL,
        completed_at TEXT,
        status TEXT NOT NULL,
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
        risk_category TEXT,
        clinical_pattern TEXT,
        clinical_notes TEXT,
        full_payload_json TEXT,
        FOREIGN KEY (patient_id) REFERENCES patients (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    await _ensureColumns(db);
  }

  /// Self-healing migration checking existing tables and adding any missing columns
  Future<void> _ensureColumns(Database db) async {
    try {
      final patientCols = await _getTableColumns(db, 'patients');
      if (!patientCols.contains('backend_id')) {
        await db.execute('ALTER TABLE patients ADD COLUMN backend_id INTEGER');
      }
      if (!patientCols.contains('full_name')) {
        await db.execute('ALTER TABLE patients ADD COLUMN full_name TEXT');
      }
      if (!patientCols.contains('name')) {
        await db.execute('ALTER TABLE patients ADD COLUMN name TEXT');
      }
      if (!patientCols.contains('village')) {
        await db.execute('ALTER TABLE patients ADD COLUMN village TEXT');
      }
      if (!patientCols.contains('occupation')) {
        await db.execute('ALTER TABLE patients ADD COLUMN occupation TEXT');
      }
      if (!patientCols.contains('smoking_status')) {
        await db.execute('ALTER TABLE patients ADD COLUMN smoking_status TEXT');
      }
      if (!patientCols.contains('updated_at')) {
        await db.execute('ALTER TABLE patients ADD COLUMN updated_at TEXT');
      }
      if (!patientCols.contains('height_cm')) {
        await db.execute('ALTER TABLE patients ADD COLUMN height_cm REAL');
      }
      if (!patientCols.contains('weight_kg')) {
        await db.execute('ALTER TABLE patients ADD COLUMN weight_kg REAL');
      }
      if (!patientCols.contains('phone')) {
        await db.execute('ALTER TABLE patients ADD COLUMN phone TEXT');
      }
      if (!patientCols.contains('medical_history')) {
        await db.execute('ALTER TABLE patients ADD COLUMN medical_history TEXT');
      }
    } catch (e) {
      debugPrint('[DatabaseHelper] Patient table schema verification note: $e');
    }

    try {
      final screeningCols = await _getTableColumns(db, 'screenings');
      if (!screeningCols.contains('backend_id')) {
        await db.execute('ALTER TABLE screenings ADD COLUMN backend_id INTEGER');
      }
      if (!screeningCols.contains('patient_backend_id')) {
        await db.execute('ALTER TABLE screenings ADD COLUMN patient_backend_id INTEGER');
      }
      if (!screeningCols.contains('started_at')) {
        await db.execute('ALTER TABLE screenings ADD COLUMN started_at TEXT');
      }
      if (!screeningCols.contains('completed_at')) {
        await db.execute('ALTER TABLE screenings ADD COLUMN completed_at TEXT');
      }
      if (!screeningCols.contains('status')) {
        await db.execute('ALTER TABLE screenings ADD COLUMN status TEXT');
      }
      if (!screeningCols.contains('risk_category')) {
        await db.execute('ALTER TABLE screenings ADD COLUMN risk_category TEXT');
      }
      if (!screeningCols.contains('full_payload_json')) {
        await db.execute('ALTER TABLE screenings ADD COLUMN full_payload_json TEXT');
      }
    } catch (e) {
      debugPrint('[DatabaseHelper] Screening table schema verification note: $e');
    }
  }

  Future<Set<String>> _getTableColumns(Database db, String tableName) async {
    final info = await db.rawQuery('PRAGMA table_info($tableName)');
    return info.map((row) => (row['name'] as String).toLowerCase()).toSet();
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

  Future<Patient?> getPatientByBackendId(int backendId) async {
    final db = await database;
    final maps = await db.query('patients', where: 'backend_id = ?', whereArgs: [backendId]);
    if (maps.isNotEmpty) {
      return Patient.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updatePatientBackendId(String localId, int backendId) async {
    final db = await database;
    await db.update(
      'patients',
      {'backend_id': backendId},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<List<Patient>> getAllPatients() async {
    final db = await database;
    final maps = await db.query('patients', orderBy: 'created_at DESC');
    return maps.map((m) => Patient.fromMap(m)).toList();
  }

  Future<List<Patient>> searchPatients(String query) async {
    final db = await database;
    final q = '%${query.toLowerCase()}%';
    final maps = await db.query(
      'patients',
      where: 'LOWER(full_name) LIKE ? OR LOWER(name) LIKE ? OR LOWER(village) LIKE ? OR LOWER(occupation) LIKE ?',
      whereArgs: [q, q, q, q],
      orderBy: 'full_name ASC',
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

  Future<int> updateScreening(ScreeningSession session) async {
    final db = await database;
    return await db.update(
      'screenings',
      session.toDbMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<void> updateScreeningBackendId(String localId, int backendId) async {
    final db = await database;
    await db.update(
      'screenings',
      {'backend_id': backendId},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<int> deleteScreening(String id) async {
    final db = await database;
    return await db.delete('screenings', where: 'id = ?', whereArgs: [id]);
  }

  Future<ScreeningSession?> getScreeningById(String id) async {
    final db = await database;
    final maps = await db.query('screenings', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      final patient = await getPatient(maps.first['patient_id'] as String);
      return ScreeningSession.fromDbMap(maps.first, attachedPatient: patient);
    }
    return null;
  }

  Future<ScreeningSession?> getScreeningByBackendId(int backendId) async {
    final db = await database;
    final maps = await db.query('screenings', where: 'backend_id = ?', whereArgs: [backendId]);
    if (maps.isNotEmpty) {
      final patientId = maps.first['patient_id'] as String;
      final patient = await getPatient(patientId);
      return ScreeningSession.fromDbMap(maps.first, attachedPatient: patient);
    }
    return null;
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
          await db.rawQuery('SELECT COUNT(*) FROM screenings WHERE risk_level LIKE ? OR risk_category LIKE ?', ['%low%', '%low%']),
        ) ??
        0;
    final modRisk = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM screenings WHERE risk_level LIKE ? OR risk_category LIKE ?', ['%moderate%', '%moderate%']),
        ) ??
        0;
    final highRisk = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM screenings WHERE risk_level LIKE ? OR risk_category LIKE ?', ['%high%', '%high%']),
        ) ??
        0;
    final critRisk = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM screenings WHERE risk_level LIKE ? OR risk_category LIKE ?', ['%critical%', '%critical%']),
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
