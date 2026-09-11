import 'package:flutter_test/flutter_test.dart';
import 'package:swasthai/models/patient_model.dart';
import 'package:swasthai/models/questionnaire_model.dart';
import 'package:swasthai/models/risk_result_model.dart';
import 'package:swasthai/models/screening_session_model.dart';
import 'package:swasthai/models/sensor_reading_model.dart';

void main() {
  group('Patient API DTO Serialization', () {
    test('Patient toApiJson produces valid FastAPI PatientCreate schema', () {
      final patient = Patient(
        id: 'local-uuid-1',
        fullName: 'Ramesh Pawar',
        age: 58,
        gender: Gender.male,
        village: 'Baramati',
        occupation: 'Farmer',
        smokingStatus: 'Current smoker',
      );

      final apiJson = patient.toApiJson();
      expect(apiJson['full_name'], equals('Ramesh Pawar'));
      expect(apiJson['age'], equals(58));
      expect(apiJson['gender'], equals('male'));
      expect(apiJson['village'], equals('Baramati'));
      expect(apiJson['occupation'], equals('Farmer'));
      expect(apiJson['smoking_status'], equals('Current smoker'));
    });

    test('Patient fromApiJson correctly parses FastAPI PatientResponse', () {
      final responseMap = {
        'id': 42,
        'full_name': 'Sunita Deshmukh',
        'age': 49,
        'gender': 'Female',
        'village': 'Shirur',
        'occupation': 'Homemaker',
        'smoking_status': 'Non-smoker',
        'created_at': '2026-09-12T04:00:00.000000',
        'updated_at': '2026-09-12T04:00:00.000000',
      };

      final patient = Patient.fromApiJson(responseMap, localId: 'local-uuid-2');
      expect(patient.id, equals('local-uuid-2'));
      expect(patient.backendId, equals(42));
      expect(patient.fullName, equals('Sunita Deshmukh'));
      expect(patient.age, equals(49));
      expect(patient.gender, equals(Gender.female));
      expect(patient.village, equals('Shirur'));
      expect(patient.smokingStatus, equals('Non-smoker'));
    });
  });

  group('Questionnaire API DTO Serialization & Mismatch Resolution', () {
    test('Questionnaire toApiJson correctly converts string/int fields to booleans', () {
      final q = QuestionnaireResponse(
        screeningId: 'screen-123',
        smokingStatus: 'Current smoker',
        yearsSmoked: 15.0,
        cigarettesPerDay: 10,
        biomassExposure: 'High/Daily',
        breathlessness: 2,
        chronicCough: true,
        phlegm: false,
        wheezing: true,
        recurrentRespiratoryProblems: true,
      );

      final apiJson = q.toApiJson();
      expect(apiJson['smoking_status'], equals('Current smoker'));
      expect(apiJson['years_smoked'], equals(15));
      expect(apiJson['cigarettes_per_day'], equals(10));
      expect(apiJson['biomass_exposure'], isTrue);
      expect(apiJson['breathlessness'], isTrue);
      expect(apiJson['chronic_cough'], isTrue);
      expect(apiJson['phlegm'], isFalse);
      expect(apiJson['wheezing'], isTrue);
      expect(apiJson['recurrent_respiratory_problems'], isTrue);
    });

    test('Questionnaire fromApiJson correctly parses backend boolean fields into rich client types', () {
      final backendResponse = {
        'id': 101,
        'screening_id': 55,
        'smoking_status': 'Former smoker',
        'years_smoked': 12,
        'cigarettes_per_day': 8,
        'biomass_exposure': true,
        'breathlessness': true,
        'chronic_cough': false,
        'phlegm': true,
        'wheezing': false,
        'recurrent_respiratory_problems': true,
        'created_at': '2026-09-12T04:00:00.000000',
      };

      final q = QuestionnaireResponse.fromApiJson(backendResponse, localScreeningId: 'local-screen-55');
      expect(q.screeningId, equals('local-screen-55'));
      expect(q.smokingStatus, equals('Former smoker'));
      expect(q.yearsSmoked, equals(12.0));
      expect(q.cigarettesPerDay, equals(8));
      expect(q.biomassExposure, equals('High/Daily'));
      expect(q.breathlessness, equals(1));
      expect(q.chronicCough, isFalse);
      expect(q.phlegm, isTrue);
      expect(q.recurrentRespiratoryProblems, isTrue);
    });
  });

  group('SensorReading API DTO Serialization', () {
    test('SensorReading toApiJson serializes numeric float metrics', () {
      final reading = SensorReading(
        id: 'sr-1',
        screeningId: 'sc-1',
        timestamp: DateTime(2026, 9, 12, 4, 15),
        spo2: 96,
        heartRate: 72,
        pressure: 24.5,
        coughActivity: 0.15,
      );

      final apiJson = reading.toApiJson();
      expect(apiJson['spo2'], equals(96.0));
      expect(apiJson['heart_rate'], equals(72.0));
      expect(apiJson['pressure'], equals(24.5));
      expect(apiJson['cough_activity'], equals(0.15));
    });

    test('SensorReading fromApiJson correctly reconstructs model', () {
      final backendJson = {
        'id': 201,
        'screening_id': 77,
        'spo2': 94.0,
        'heart_rate': 80.0,
        'pressure': 28.2,
        'cough_activity': 0.85,
        'timestamp': '2026-09-12T04:15:00.000000',
      };

      final sr = SensorReading.fromApiJson(backendJson, localScreeningId: 'local-sc-77');
      expect(sr.id, equals('201'));
      expect(sr.screeningId, equals('local-sc-77'));
      expect(sr.spo2, equals(94));
      expect(sr.heartRate, equals(80));
      expect(sr.pressure, closeTo(28.2, 0.01));
      expect(sr.coughActivity, closeTo(0.85, 0.01));
    });
  });

  group('RiskResult API DTO Deserialization', () {
    test('RiskResult fromApiJson parses ML assessment output accurately', () {
      final backendRisk = {
        'id': 301,
        'screening_id': 77,
        'risk_score': 68.4,
        'risk_category': 'Moderate Risk',
        'contributing_factors': [
          'High Biomass Smoke Exposure',
          'Elevated Cough Acoustic Score',
          'Reduced Airflow Peak Pressure',
        ],
        'recommendation': 'Clinical Evaluation Recommended. Advise spirometry assessment and ventilation improvement.',
        'created_at': '2026-09-12T04:16:00.000000',
      };

      final result = RiskResult.fromApiJson(backendRisk, localScreeningId: 'local-sc-77');
      expect(result.screeningId, equals('local-sc-77'));
      expect(result.riskScore, equals(68));
      expect(result.riskCategory, equals('Moderate Risk'));
      expect(result.riskLevel, equals(RiskLevel.moderate));
      expect(result.contributingFactors.length, equals(3));
      expect(result.recommendation, contains('Clinical Evaluation Recommended'));
    });
  });
}
