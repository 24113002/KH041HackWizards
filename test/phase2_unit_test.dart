import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:swasthai/controllers/current_screening_controller.dart';
import 'package:swasthai/data/database_helper.dart';
import 'package:swasthai/models/patient_model.dart';
import 'package:swasthai/models/questionnaire_model.dart';
import 'package:swasthai/models/screening_result_model.dart';
import 'package:swasthai/models/screening_session_model.dart';
import 'package:swasthai/repositories/patient_repository.dart';
import 'package:swasthai/repositories/screening_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 2 Architecture & Local-First Workflow Tests', () {
    final patientRepo = LocalPatientRepository(dbHelper: DatabaseHelper.instance);
    final screeningRepo = LocalScreeningRepository(dbHelper: DatabaseHelper.instance);

    test('1. Patient model validation and BMI / predicted metrics calculation', () {
      final validPatient = Patient(
        id: 'val-p-1',
        fullName: 'Ramesh Kulkarni',
        age: 45,
        gender: Gender.male,
        heightCm: 170.0,
        weightKg: 70.0,
      );
      expect(validPatient.validate(), isNull);
      expect(validPatient.bmi, closeTo(24.22, 0.05));
      expect(validPatient.predictedFvc, greaterThan(3.0));
      expect(validPatient.predictedFev1, greaterThan(2.5));
      expect(validPatient.predictedPef, greaterThan(400.0));

      final invalidPatient = Patient(
        id: 'val-p-2',
        fullName: '',
        age: 150,
        gender: Gender.female,
      );
      expect(invalidPatient.validate(), isNotNull);
    });

    test('2. Automatic demo patient seeding on initial repository query', () async {
      final patients = await patientRepo.getPatients();
      expect(patients.isNotEmpty, isTrue);
      expect(patients.any((p) => p.fullName.contains('Rahul Patil') || p.fullName.contains('Anita Sharma')), isTrue);
    });

    test('3. Create and retrieve patient in LocalPatientRepository', () async {
      final patient = Patient(
        id: 'test-p-100',
        fullName: 'Rahul Patil',
        age: 52,
        gender: Gender.male,
        village: 'Khed',
        occupation: 'Farmer',
        smokingStatus: 'Current smoker',
      );

      await patientRepo.createPatient(patient);
      final retrieved = await patientRepo.getPatientById('test-p-100');

      expect(retrieved, isNotNull);
      expect(retrieved!.fullName, equals('Rahul Patil'));
      expect(retrieved.age, equals(52));
      expect(retrieved.village, equals('Khed'));
      expect(retrieved.smokingStatus, equals('Current smoker'));
    });

    test('4. Case-insensitive search patient by name or village', () async {
      final p1 = Patient(
        id: 'test-p-101',
        fullName: 'Anita Sharma',
        age: 46,
        gender: Gender.female,
        village: 'Shirur',
        occupation: 'Homemaker',
        smokingStatus: 'Non-smoker',
      );
      await patientRepo.createPatient(p1);

      final searchResults = await patientRepo.searchPatients('anita');
      expect(searchResults.any((p) => p.id == 'test-p-101'), isTrue);

      final villageResults = await patientRepo.searchPatients('shirur');
      expect(villageResults.any((p) => p.id == 'test-p-101'), isTrue);
    });

    test('5. Screening session creation and state lifecycle in CurrentScreeningController', () {
      final ctrl = CurrentScreeningController();
      final patient = Patient(
        id: 'test-p-102',
        fullName: 'Vijay More',
        age: 61,
        gender: Gender.male,
        village: 'Baramati',
        occupation: 'Mill worker',
        smokingStatus: 'Former smoker',
      );

      ctrl.startNewSession(patient);

      expect(ctrl.isSessionActive, isTrue);
      expect(ctrl.session, isNotNull);
      expect(ctrl.session!.patientId, equals('test-p-102'));
      expect(ctrl.session!.status, equals(ScreeningStatus.inProgress));
      expect(ctrl.sensorReading, isNotNull);
      expect(ctrl.sensorReading!.spo2, equals(97));
      expect(ctrl.sensorReading!.heartRate, equals(82));
    });

    test('6. Save questionnaire responses to current screening state', () {
      final ctrl = CurrentScreeningController();
      final patient = Patient(
        id: 'test-p-103',
        fullName: 'Sunita Rao',
        age: 50,
        gender: Gender.female,
      );

      ctrl.startNewSession(patient);

      const q = QuestionnaireResponse(
        smokingStatus: 'Former smoker',
        yearsSmoked: 12.0,
        cigarettesPerDay: 5,
        biomassExposure: 'High/Daily',
        breathlessness: 2,
        chronicCough: true,
        phlegm: true,
        wheezing: false,
        recurrentRespiratoryProblems: true,
      );

      ctrl.updateQuestionnaire(q);

      expect(ctrl.questionnaire.breathlessness, equals(2));
      expect(ctrl.questionnaire.chronicCough, isTrue);
      expect(ctrl.questionnaire.phlegm, isTrue);
      expect(ctrl.questionnaire.biomassExposure, equals('High/Daily'));
      expect(ctrl.questionnaire.symptomScore, greaterThan(5));
    });

    test('7. Complete screening session and retrieve from ScreeningRepository history', () async {
      final ctrl = CurrentScreeningController();
      final patient = Patient(
        id: 'test-p-104',
        fullName: 'Ganesh Shinde',
        age: 58,
        gender: Gender.male,
        village: 'Pune',
      );
      await patientRepo.createPatient(patient);

      ctrl.startNewSession(patient);

      const q = QuestionnaireResponse(
        breathlessness: 1,
        chronicCough: false,
      );
      ctrl.updateQuestionnaire(q);

      final mockResult = RiskResult.mock(
        screeningId: ctrl.session!.id,
        score: 12,
        category: 'Low Risk',
      );
      ctrl.updateRiskResult(mockResult);

      final ok = await ctrl.completeSession(screeningRepo, clinicalNotes: 'Routine wellness check');
      expect(ok, isTrue);

      final history = await screeningRepo.getScreeningsForPatient('test-p-104');
      expect(history.length, equals(1));
      expect(history.first.status, equals(ScreeningStatus.completed));
      expect(history.first.riskCategory, equals('Low Risk'));
      expect(history.first.clinicalNotes, equals('Routine wellness check'));
    });
  });
}
