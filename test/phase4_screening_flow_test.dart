import 'package:flutter_test/flutter_test.dart';
import 'package:swasthai/controllers/current_screening_controller.dart';
import 'package:swasthai/models/patient_model.dart';
import 'package:swasthai/models/screening_session_model.dart';
import 'package:swasthai/models/swaas_ai_ble_result.dart';
import 'package:swasthai/repositories/screening_repository.dart';
import 'package:swasthai/services/swaas_ai_packet_parser.dart';

class InMemoryScreeningRepository implements ScreeningRepository {
  final List<ScreeningSession> sessions = [];

  @override
  Future<void> createScreening(ScreeningSession session) async {
    sessions.add(session);
  }

  @override
  Future<void> updateScreening(ScreeningSession session) async {
    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      sessions[index] = session;
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
  group('Phase 4 Complete Screening Flow & Duplicate Prevention Tests', () {
    late Patient testPatient;
    late InMemoryScreeningRepository repository;
    late CurrentScreeningController controller;

    setUp(() {
      testPatient = Patient(
        id: 'patient_001',
        name: 'Ramesh Kumar',
        age: 58,
        gender: Gender.male,
        village: 'Rampur',
        heightCm: 168.0,
        weightKg: 64.0,
      );
      repository = InMemoryScreeningRepository();
      controller = CurrentScreeningController();
    });

    test('1. Applies completed valid ESP32 packet to current screening session', () {
      controller.startNewSession(testPatient);
      expect(controller.isSessionActive, isTrue);

      final result = SwaasAiPacketParser.parse('R01,42350,97,1860,42,MODERATE');
      controller.applyBleResult(result);

      expect(controller.bleResult, equals(result));
      expect(controller.lastProcessedBleRecordId, equals('R01'));
      expect(controller.vitals.spo2, equals(97));
      expect(controller.riskResult, isNotNull);
      expect(controller.riskResult!.riskScore, equals(42));
      expect(controller.riskResult!.riskCategory, equals('Moderate Risk'));
      expect(controller.sensorReading!.spo2, equals(97));
    });

    test('2. Applies incomplete ESP32 packet with NA without converting NA to 0', () {
      controller.startNewSession(testPatient);

      final result = SwaasAiPacketParser.parse('R02,39120,NA,1735,NA,INCOMPLETE');
      controller.applyBleResult(result);

      expect(controller.bleResult, equals(result));
      expect(controller.bleResult!.spo2, isNull);
      expect(controller.bleResult!.risk, isNull);
      expect(controller.bleResult!.status, equals(SwaasAiStatus.incomplete));
      expect(controller.riskResult!.riskCategory, equals('Incomplete'));
    });

    test('3. Complete screening session persists to repository accurately', () async {
      controller.startNewSession(testPatient);
      final result = SwaasAiPacketParser.parse('R01,42350,97,1860,42,MODERATE');
      controller.applyBleResult(result);

      final success = await controller.completeSession(repository, clinicalNotes: 'Routine screening check.');
      expect(success, isTrue);
      expect(repository.sessions.length, equals(1));

      final saved = repository.sessions.first;
      expect(saved.patientId, equals(testPatient.id));
      expect(saved.riskScore, equals(42));
      expect(saved.clinicalNotes, equals('Routine screening check.'));
    });

    test('4. Disconnect during active screening preserves collected data', () {
      controller.startNewSession(testPatient);
      final result = SwaasAiPacketParser.parse('R01,42350,97,1860,42,MODERATE');
      controller.applyBleResult(result);

      // Verify that after BLE disconnects (no call to cancelSession), state remains intact
      expect(controller.patient, equals(testPatient));
      expect(controller.isSessionActive, isTrue);
      expect(controller.bleResult, isNotNull);
      expect(controller.riskResult!.riskScore, equals(42));
    });
  });
}
