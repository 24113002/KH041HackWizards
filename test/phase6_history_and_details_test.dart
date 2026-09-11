import 'package:flutter_test/flutter_test.dart';
import 'package:swasthai/controllers/screening_history_controller.dart';
import 'package:swasthai/models/patient_model.dart';
import 'package:swasthai/models/questionnaire_model.dart';
import 'package:swasthai/models/screening_result_model.dart';
import 'package:swasthai/models/screening_session_model.dart';
import 'package:swasthai/models/sensor_data_model.dart';
import 'package:swasthai/models/sensor_reading_model.dart';
import 'package:swasthai/models/swaas_ai_ble_result.dart';
import 'package:swasthai/repositories/screening_repository.dart';
import 'package:swasthai/services/swaas_ai_packet_parser.dart';

class MockScreeningRepository implements ScreeningRepository {
  final List<ScreeningSession> sessions = [];

  @override
  Future<void> createScreening(ScreeningSession session) async {
    final idx = sessions.indexWhere((s) => s.id == session.id);
    if (idx != -1) {
      sessions[idx] = session;
    } else {
      sessions.add(session);
    }
  }

  @override
  Future<void> updateScreening(ScreeningSession session) async {
    final idx = sessions.indexWhere((s) => s.id == session.id);
    if (idx != -1) {
      sessions[idx] = session;
    } else {
      sessions.add(session);
    }
  }

  @override
  Future<List<ScreeningSession>> getScreenings() async {
    return List.unmodifiable(sessions);
  }

  @override
  Future<List<ScreeningSession>> getScreeningsForPatient(String patientId) async {
    return sessions.where((s) => s.patientId == patientId).toList();
  }

  @override
  Future<ScreeningSession?> getScreeningById(String id) async {
    return sessions.where((s) => s.id == id).firstOrNull;
  }

  @override
  Future<void> deleteScreening(String id) async {
    sessions.removeWhere((s) => s.id == id);
  }
}

void main() {
  group('Phase 6 — Screening History, Details & Patient Isolation Tests', () {
    late Patient patientRahul;
    late Patient patientAnita;
    late MockScreeningRepository repository;
    late ScreeningHistoryController historyController;

    setUp(() {
      patientRahul = Patient(
        id: 'p_rahul_101',
        name: 'Rahul Patil',
        age: 52,
        gender: Gender.male,
        village: 'Khed Shivapur',
      );

      patientAnita = Patient(
        id: 'p_anita_102',
        name: 'Anita Deshmukh',
        age: 48,
        gender: Gender.female,
        village: 'Saswad',
      );

      repository = MockScreeningRepository();
      historyController = ScreeningHistoryController(repository: repository);
    });

    // -------------------------------------------------------------
    // 1. History Loading & Persistence Tests
    // -------------------------------------------------------------
    test('1. Loads and parses complete screening records into history controller', () async {
      final bleResult = SwaasAiPacketParser.parse('R01,42350,97,1860,42,MODERATE');

      final session1 = ScreeningSession(
        id: 'session_001',
        patientId: patientRahul.id,
        startedAt: DateTime.now().subtract(const Duration(hours: 2)),
        status: ScreeningStatus.completed,
        riskScore: bleResult.risk,
        riskCategory: bleResult.status.label,
        patient: patientRahul,
        vitals: VitalsReading(heartRate: 0, spo2: 97, ppgValue: 0.5, timestamp: DateTime.now()),
        sensorReading: SensorReading(id: 'R01', screeningId: 'session_001', timestamp: DateTime.now(), spo2: 97, pressure: 4.235),
        questionnaire: const QuestionnaireResponse(smokingStatus: 'Former smoker', yearsSmoked: 25, cigarettesPerDay: 10, breathlessness: 2),
        riskResult: const RiskResult(riskScore: 42, riskCategory: 'Moderate Risk', contributingFactors: ['Smoking history', 'Breathlessness']),
      );

      await repository.createScreening(session1);
      await historyController.loadHistory();

      expect(historyController.history.length, equals(1));
      final loaded = historyController.history.first;
      expect(loaded.id, equals('session_001'));
      expect(loaded.patient?.name, equals('Rahul Patil'));
      expect(loaded.riskScore, equals(42));
      expect(loaded.riskCategory, equals('Moderate Risk'));
      expect(loaded.status, equals(ScreeningStatus.completed));
      expect(loaded.sensorReading?.id, equals('R01'));
      expect(loaded.vitals.spo2, equals(97));
    });

    // -------------------------------------------------------------
    // 2. Patient-Wise History & Patient Isolation Tests
    // -------------------------------------------------------------
    test('2. Patient-wise history strictly isolates screenings by patient ID', () async {
      final sessionRahul1 = ScreeningSession(
        id: 'session_r1',
        patientId: patientRahul.id,
        startedAt: DateTime.now().subtract(const Duration(days: 2)),
        status: ScreeningStatus.completed,
        riskScore: 42,
        riskCategory: 'Moderate Risk',
        patient: patientRahul,
      );

      final sessionRahul2 = ScreeningSession(
        id: 'session_r2',
        patientId: patientRahul.id,
        startedAt: DateTime.now().subtract(const Duration(days: 1)),
        status: ScreeningStatus.completed,
        riskScore: 35,
        riskCategory: 'Moderate Risk',
        patient: patientRahul,
      );

      final sessionAnita = ScreeningSession(
        id: 'session_a1',
        patientId: patientAnita.id,
        startedAt: DateTime.now(),
        status: ScreeningStatus.completed,
        riskScore: 15,
        riskCategory: 'Low Risk',
        patient: patientAnita,
      );

      await repository.createScreening(sessionRahul1);
      await repository.createScreening(sessionRahul2);
      await repository.createScreening(sessionAnita);
      await historyController.loadHistory();

      final rahulScreenings = historyController.getScreeningsForPatient(patientRahul.id);
      final anitaScreenings = historyController.getScreeningsForPatient(patientAnita.id);

      expect(rahulScreenings.length, equals(2));
      expect(rahulScreenings.every((s) => s.patientId == patientRahul.id), isTrue);
      expect(rahulScreenings.any((s) => s.patientId == patientAnita.id), isFalse);

      expect(anitaScreenings.length, equals(1));
      expect(anitaScreenings.first.patientId, equals(patientAnita.id));
      expect(anitaScreenings.first.id, equals('session_a1'));
    });

    // -------------------------------------------------------------
    // 3. Search & Filter Tests
    // -------------------------------------------------------------
    test('3. Searches history by patient name, village, and screening record ID', () async {
      final session1 = ScreeningSession(
        id: 'sess_101',
        patientId: patientRahul.id,
        startedAt: DateTime.now(),
        riskCategory: 'Moderate Risk',
        patient: patientRahul,
        sensorReading: SensorReading(id: 'R01', screeningId: 'sess_101', timestamp: DateTime.now()),
      );

      final session2 = ScreeningSession(
        id: 'sess_102',
        patientId: patientAnita.id,
        startedAt: DateTime.now(),
        riskCategory: 'Low Risk',
        patient: patientAnita,
        sensorReading: SensorReading(id: 'R02', screeningId: 'sess_102', timestamp: DateTime.now()),
      );

      await repository.createScreening(session1);
      await repository.createScreening(session2);
      await historyController.loadHistory();

      // Search by Patient Name
      historyController.searchHistory('Rahul');
      expect(historyController.filteredHistory.length, equals(1));
      expect(historyController.filteredHistory.first.patient?.name, equals('Rahul Patil'));

      // Search by Village
      historyController.searchHistory('Saswad');
      expect(historyController.filteredHistory.length, equals(1));
      expect(historyController.filteredHistory.first.patient?.name, equals('Anita Deshmukh'));

      // Search by Record ID
      historyController.searchHistory('R01');
      expect(historyController.filteredHistory.length, equals(1));
      expect(historyController.filteredHistory.first.sensorReading?.id, equals('R01'));

      // Non-matching Search
      historyController.searchHistory('NonExistentName');
      expect(historyController.filteredHistory.isEmpty, isTrue);

      historyController.clearFilters();
      expect(historyController.filteredHistory.length, equals(2));
    });

    test('4. Filters history by status and risk category accurately', () async {
      final sessionComplete = ScreeningSession(
        id: 'sess_c1',
        patientId: patientRahul.id,
        startedAt: DateTime.now(),
        status: ScreeningStatus.completed,
        riskScore: 75,
        riskCategory: 'High Risk',
        patient: patientRahul,
      );

      final sessionIncomplete = ScreeningSession(
        id: 'sess_inc1',
        patientId: patientAnita.id,
        startedAt: DateTime.now(),
        status: ScreeningStatus.incomplete,
        riskScore: null,
        riskCategory: 'Incomplete',
        patient: patientAnita,
      );

      final sessionModerate = ScreeningSession(
        id: 'sess_m1',
        patientId: patientRahul.id,
        startedAt: DateTime.now(),
        status: ScreeningStatus.completed,
        riskScore: 42,
        riskCategory: 'Moderate Risk',
        patient: patientRahul,
      );

      await repository.createScreening(sessionComplete);
      await repository.createScreening(sessionIncomplete);
      await repository.createScreening(sessionModerate);
      await historyController.loadHistory();

      // Filter Completed
      historyController.setFilterCategory('Completed');
      expect(historyController.filteredHistory.length, equals(2));

      // Filter Incomplete
      historyController.setFilterCategory('Incomplete');
      expect(historyController.filteredHistory.length, equals(1));
      expect(historyController.filteredHistory.first.status, equals(ScreeningStatus.incomplete));

      // Filter Higher Risk
      historyController.setFilterCategory('Higher Risk');
      expect(historyController.filteredHistory.length, equals(1));
      expect(historyController.filteredHistory.first.riskCategory, equals('High Risk'));

      // Filter Moderate Risk
      historyController.setFilterCategory('Moderate Risk');
      expect(historyController.filteredHistory.length, equals(1));
      expect(historyController.filteredHistory.first.riskScore, equals(42));
    });

    // -------------------------------------------------------------
    // 4. Sorting Tests
    // -------------------------------------------------------------
    test('5. Sorts history correctly between Newest First and Oldest First', () async {
      final oldDate = DateTime(2026, 9, 1, 10, 0);
      final newDate = DateTime(2026, 9, 11, 10, 0);

      final oldSession = ScreeningSession(
        id: 'sess_old',
        patientId: patientRahul.id,
        startedAt: oldDate,
        patient: patientRahul,
      );

      final newSession = ScreeningSession(
        id: 'sess_new',
        patientId: patientAnita.id,
        startedAt: newDate,
        patient: patientAnita,
      );

      await repository.createScreening(oldSession);
      await repository.createScreening(newSession);
      await historyController.loadHistory();

      // Default: Newest First
      expect(historyController.sortOrder, equals(ScreeningSortOrder.newestFirst));
      expect(historyController.history.first.id, equals('sess_new'));
      expect(historyController.history.last.id, equals('sess_old'));

      // Toggle to Oldest First
      historyController.toggleSortOrder();
      expect(historyController.sortOrder, equals(ScreeningSortOrder.oldestFirst));
      expect(historyController.history.first.id, equals('sess_old'));
      expect(historyController.history.last.id, equals('sess_new'));
    });

    // -------------------------------------------------------------
    // 5. Incomplete Screening & NA Preservation Tests
    // -------------------------------------------------------------
    test('6. Incomplete screening record preserves NA as null without generating 0 or fake scores', () async {
      final incompleteBle = SwaasAiPacketParser.parse('R02,39120,NA,1735,NA,INCOMPLETE');

      final session = ScreeningSession(
        id: 'sess_incomplete_002',
        patientId: patientAnita.id,
        startedAt: DateTime.now(),
        status: ScreeningStatus.incomplete,
        riskScore: incompleteBle.risk, // strictly null
        riskCategory: 'Incomplete',
        patient: patientAnita,
        vitals: VitalsReading(heartRate: 0, spo2: 0, ppgValue: 0.0, timestamp: DateTime.now()),
        sensorReading: SensorReading(id: 'R02', screeningId: 'sess_incomplete_002', timestamp: DateTime.now(), spo2: null, pressure: 3.912),
        riskResult: const RiskResult(riskScore: 0, riskCategory: 'Incomplete', contributingFactors: ['SpO₂: Not Available (NA)']),
      );

      await repository.createScreening(session);
      await historyController.loadHistory();

      final record = historyController.history.first;
      expect(record.status, equals(ScreeningStatus.incomplete));
      expect(record.riskScore, isNull);
      expect(record.riskCategory, equals('Incomplete'));
      expect(record.sensorReading?.spo2, isNull);
    });

    // -------------------------------------------------------------
    // 6. Safe Deletion Tests
    // -------------------------------------------------------------
    test('7. Deletes individual screening without affecting patient or other screenings', () async {
      final session1 = ScreeningSession(id: 's_del_1', patientId: patientRahul.id, startedAt: DateTime.now(), patient: patientRahul);
      final session2 = ScreeningSession(id: 's_del_2', patientId: patientRahul.id, startedAt: DateTime.now(), patient: patientRahul);

      await repository.createScreening(session1);
      await repository.createScreening(session2);
      await historyController.loadHistory();
      expect(historyController.history.length, equals(2));

      final deleted = await historyController.deleteScreening('s_del_1');
      expect(deleted, isTrue);
      expect(historyController.history.length, equals(1));
      expect(historyController.history.first.id, equals('s_del_2'));
    });
  });
}
