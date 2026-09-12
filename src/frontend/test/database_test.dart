import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:swasthai/data/database_helper.dart';
import 'package:swasthai/models/patient_model.dart';
import 'package:swasthai/models/questionnaire_model.dart';
import 'package:swasthai/models/screening_result_model.dart';
import 'package:swasthai/models/screening_session_model.dart';
import 'package:swasthai/models/sensor_data_model.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseHelper CRUD Tests', () {
    final dbHelper = DatabaseHelper.instance;

    test('Insert and retrieve patient', () async {
      final patient = Patient(
        id: 'test-pt-1',
        name: 'Sunita Sharma',
        age: 52,
        gender: Gender.female,
        heightCm: 158.0,
        weightKg: 62.0,
        phone: '9876543210',
        medicalHistory: 'Hypertension',
      );

      await dbHelper.insertPatient(patient);
      final retrieved = await dbHelper.getPatient('test-pt-1');

      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('Sunita Sharma'));
      expect(retrieved.age, equals(52));
      expect(retrieved.gender, equals(Gender.female));
    });

    test('Insert screening session and query dashboard stats', () async {
      final patient = Patient(
        id: 'test-pt-2',
        name: 'Amit Patel',
        age: 38,
        gender: Gender.male,
        heightCm: 175.0,
        weightKg: 74.0,
      );
      await dbHelper.insertPatient(patient);

      final session = ScreeningSession(
        id: 'sess-1',
        patientId: patient.id,
        timestamp: DateTime.now(),
        patient: patient,
        vitals: VitalsReading(
          heartRate: 76,
          spo2: 98,
          ppgValue: 0.5,
          timestamp: DateTime.now(),
        ),
        spirometry: const SpirometrySummary(
          fev1: 3.5,
          fvc: 4.2,
          fev1FvcRatio: 0.83,
          pefLpm: 480.0,
          forcedExpiratoryTimeSec: 3.8,
        ),
        acoustic: const AcousticSummary(
          coughCount: 0,
          peakRms: 0.1,
          averageRms: 0.05,
          wheezeDetected: false,
        ),
        questionnaire: const QuestionnaireResponse(
          mmrcDyspneaGrade: 0,
        ),
        riskResult: const RiskResult(
          overallScore: 8,
          riskLevel: RiskLevel.low,
          clinicalPattern: ClinicalPattern.normal,
          findings: [],
          recommendations: ['Routine follow-up'],
          emergencyFlag: false,
          heartRate: 76,
          spo2: 98,
          fev1: 3.5,
          fvc: 4.2,
          fev1FvcRatio: 0.83,
          pefLpm: 480.0,
          fev1PercentPredicted: 95.0,
          fvcPercentPredicted: 96.0,
          pefPercentPredicted: 94.0,
          coughCount: 0,
          symptomScore: 0,
        ),
        clinicalNotes: 'Screening passed normally.',
      );

      await dbHelper.insertScreening(session);

      final patientScreenings = await dbHelper.getScreeningsForPatient('test-pt-2');
      expect(patientScreenings.length, equals(1));
      expect(patientScreenings.first.vitals.spo2, equals(98));
      expect(patientScreenings.first.riskResult.riskLevel, equals(RiskLevel.low));

      final stats = await dbHelper.getDashboardStats();
      expect(stats['total_screenings'], greaterThanOrEqualTo(1));
      expect(stats['low_risk'], greaterThanOrEqualTo(1));
    });
  });
}
