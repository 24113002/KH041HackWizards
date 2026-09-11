import 'package:flutter_test/flutter_test.dart';
import 'package:swasthai/engine/risk_assessment_engine.dart';
import 'package:swasthai/models/patient_model.dart';
import 'package:swasthai/models/questionnaire_model.dart';
import 'package:swasthai/models/screening_result_model.dart';
import 'package:swasthai/models/sensor_data_model.dart';

void main() {
  group('RiskAssessmentEngine Tests', () {
    final healthyPatient = Patient(
      id: 'patient-1',
      name: 'Ramesh Kumar',
      age: 40,
      gender: Gender.male,
      heightCm: 172.0,
      weightKg: 70.0,
    );

    test('Predicted lung equations calculate appropriate reference values', () {
      expect(healthyPatient.predictedFvc, greaterThan(3.5));
      expect(healthyPatient.predictedFev1, greaterThan(2.8));
      expect(healthyPatient.predictedPef, greaterThan(350.0));
      expect(healthyPatient.bmi, closeTo(23.66, 0.1));
    });

    test('Healthy vitals and normal spirometry produce Low Risk and Normal Pattern', () {
      final vitals = VitalsReading(
        heartRate: 72,
        spo2: 98,
        ppgValue: 0.5,
        timestamp: DateTime.now(),
      );

      final spirometry = SpirometrySummary(
        fev1: 3.4,
        fvc: 4.1,
        fev1FvcRatio: 0.83,
        pefLpm: 460.0,
        forcedExpiratoryTimeSec: 3.5,
      );

      const acoustic = AcousticSummary(
        coughCount: 0,
        peakRms: 0.1,
        averageRms: 0.05,
        wheezeDetected: false,
      );

      const questionnaire = QuestionnaireResponse(
        mmrcDyspneaGrade: 0,
        coughFrequency: 0,
        sputumType: 0,
        wheezeSeverity: 0,
        chestDiscomfort: 0,
        smokingStatus: 0,
      );

      final result = RiskAssessmentEngine.evaluate(
        patient: healthyPatient,
        vitals: vitals,
        spirometry: spirometry,
        acoustic: acoustic,
        questionnaire: questionnaire,
      );

      expect(result.riskLevel, equals(RiskLevel.low));
      expect(result.clinicalPattern, equals(ClinicalPattern.normal));
      expect(result.emergencyFlag, isFalse);
      expect(result.overallScore, lessThan(18));
      expect(result.findings.any((f) => f.title.contains('Normal Oxygen Saturation')), isTrue);
    });

    test('Reduced FEV1/FVC ratio (< 0.70) triggers Obstructive Airway Disease pattern', () {
      final vitals = VitalsReading(
        heartRate: 82,
        spo2: 95,
        ppgValue: 0.5,
        timestamp: DateTime.now(),
      );

      // Low FEV1 causing ratio 0.55 (< 0.70)
      final spirometry = SpirometrySummary(
        fev1: 1.8,
        fvc: 3.3,
        fev1FvcRatio: 0.55,
        pefLpm: 250.0,
        forcedExpiratoryTimeSec: 4.5,
      );

      const acoustic = AcousticSummary(
        coughCount: 2,
        peakRms: 0.4,
        averageRms: 0.1,
        wheezeDetected: true,
      );

      const questionnaire = QuestionnaireResponse(
        mmrcDyspneaGrade: 2,
        coughFrequency: 2,
        wheezeSeverity: 2,
        smokingStatus: 2,
        packYears: 15.0,
      );

      final result = RiskAssessmentEngine.evaluate(
        patient: healthyPatient,
        vitals: vitals,
        spirometry: spirometry,
        acoustic: acoustic,
        questionnaire: questionnaire,
      );

      expect(result.clinicalPattern, equals(ClinicalPattern.obstructiveAirway));
      expect(result.riskLevel, isIn([RiskLevel.high, RiskLevel.critical]));
      expect(result.findings.any((f) => f.title.contains('Airflow Obstruction')), isTrue);
      expect(result.recommendations.any((r) => r.contains('Pulmonologist') || r.contains('bronchodilator')), isTrue);
    });

    test('Critical hypoxemia (SpO2 < 88%) sets emergency flag and acute pattern', () {
      final vitals = VitalsReading(
        heartRate: 128,
        spo2: 84,
        ppgValue: 0.3,
        timestamp: DateTime.now(),
      );

      final spirometry = SpirometrySummary(
        fev1: 2.0,
        fvc: 2.5,
        fev1FvcRatio: 0.80,
        pefLpm: 280.0,
        forcedExpiratoryTimeSec: 2.5,
      );

      const acoustic = AcousticSummary(
        coughCount: 4,
        peakRms: 0.8,
        averageRms: 0.3,
        wheezeDetected: false,
      );

      const questionnaire = QuestionnaireResponse(
        mmrcDyspneaGrade: 4,
        chestDiscomfort: 2,
      );

      final result = RiskAssessmentEngine.evaluate(
        patient: healthyPatient,
        vitals: vitals,
        spirometry: spirometry,
        acoustic: acoustic,
        questionnaire: questionnaire,
      );

      expect(result.emergencyFlag, isTrue);
      expect(result.riskLevel, equals(RiskLevel.critical));
      expect(result.clinicalPattern, equals(ClinicalPattern.acuteHypoxemia));
      expect(result.recommendations.any((r) => r.contains('URGENT: Administer supplemental oxygen')), isTrue);
    });
  });
}
