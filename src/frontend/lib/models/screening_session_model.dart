import 'dart:convert';
import 'patient_model.dart';
import 'sensor_data_model.dart';
import 'questionnaire_model.dart';
import 'screening_result_model.dart';

class ScreeningSession {
  final String id;
  final String patientId;
  final DateTime timestamp;
  final Patient? patient;
  final VitalsReading vitals;
  final SpirometrySummary spirometry;
  final AcousticSummary acoustic;
  final QuestionnaireResponse questionnaire;
  final RiskResult riskResult;
  final String clinicalNotes;

  ScreeningSession({
    required this.id,
    required this.patientId,
    required this.timestamp,
    this.patient,
    required this.vitals,
    required this.spirometry,
    required this.acoustic,
    required this.questionnaire,
    required this.riskResult,
    this.clinicalNotes = '',
  });

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'timestamp': timestamp.toIso8601String(),
      'heart_rate': vitals.heartRate,
      'spo2': vitals.spo2,
      'fev1': spirometry.fev1,
      'fvc': spirometry.fvc,
      'fev1_fvc_ratio': spirometry.fev1FvcRatio,
      'pef_lpm': spirometry.pefLpm,
      'cough_count': acoustic.coughCount,
      'symptom_score': questionnaire.symptomScore,
      'risk_level': riskResult.riskLevel.name,
      'risk_score': riskResult.overallScore,
      'clinical_pattern': riskResult.clinicalPattern.name,
      'clinical_notes': clinicalNotes,
      'full_payload_json': jsonEncode({
        'vitals': vitals.toMap(),
        'spirometry': spirometry.toMap(),
        'acoustic': acoustic.toMap(),
        'questionnaire': questionnaire.toMap(),
        'risk_result': riskResult.toMap(),
      }),
    };
  }

  factory ScreeningSession.fromDbMap(Map<String, dynamic> map, {Patient? attachedPatient}) {
    final payloadJson = map['full_payload_json'] as String?;
    Map<String, dynamic> payload = {};
    if (payloadJson != null && payloadJson.isNotEmpty) {
      try {
        payload = jsonDecode(payloadJson) as Map<String, dynamic>;
      } catch (_) {}
    }

    final vitals = payload['vitals'] != null
        ? VitalsReading.fromMap(Map<String, dynamic>.from(payload['vitals'] as Map))
        : VitalsReading(
            heartRate: (map['heart_rate'] as num?)?.toInt() ?? 0,
            spo2: (map['spo2'] as num?)?.toInt() ?? 0,
            ppgValue: 0.0,
            timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
          );

    final spirometry = payload['spirometry'] != null
        ? SpirometrySummary.fromMap(Map<String, dynamic>.from(payload['spirometry'] as Map))
        : SpirometrySummary(
            fev1: (map['fev1'] as num?)?.toDouble() ?? 0.0,
            fvc: (map['fvc'] as num?)?.toDouble() ?? 0.0,
            fev1FvcRatio: (map['fev1_fvc_ratio'] as num?)?.toDouble() ?? 0.0,
            pefLpm: (map['pef_lpm'] as num?)?.toDouble() ?? 0.0,
            forcedExpiratoryTimeSec: 0.0,
          );

    final acoustic = payload['acoustic'] != null
        ? AcousticSummary.fromMap(Map<String, dynamic>.from(payload['acoustic'] as Map))
        : AcousticSummary(
            coughCount: (map['cough_count'] as num?)?.toInt() ?? 0,
            peakRms: 0.0,
            averageRms: 0.0,
            wheezeDetected: false,
          );

    final questionnaire = payload['questionnaire'] != null
        ? QuestionnaireResponse.fromMap(Map<String, dynamic>.from(payload['questionnaire'] as Map))
        : const QuestionnaireResponse();

    final riskResult = payload['risk_result'] != null
        ? RiskResult.fromMap(Map<String, dynamic>.from(payload['risk_result'] as Map))
        : RiskResult(
            overallScore: (map['risk_score'] as num?)?.toInt() ?? 0,
            riskLevel: RiskLevel.values.firstWhere(
              (r) => r.name == (map['risk_level'] as String?),
              orElse: () => RiskLevel.low,
            ),
            clinicalPattern: ClinicalPattern.values.firstWhere(
              (c) => c.name == (map['clinical_pattern'] as String?),
              orElse: () => ClinicalPattern.normal,
            ),
            findings: [],
            recommendations: [],
            emergencyFlag: false,
            heartRate: vitals.heartRate,
            spo2: vitals.spo2,
            fev1: spirometry.fev1,
            fvc: spirometry.fvc,
            fev1FvcRatio: spirometry.fev1FvcRatio,
            pefLpm: spirometry.pefLpm,
            fev1PercentPredicted: 0.0,
            fvcPercentPredicted: 0.0,
            pefPercentPredicted: 0.0,
            coughCount: acoustic.coughCount,
            symptomScore: (map['symptom_score'] as num?)?.toInt() ?? 0,
          );

    return ScreeningSession(
      id: map['id'] as String,
      patientId: map['patient_id'] as String,
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      patient: attachedPatient,
      vitals: vitals,
      spirometry: spirometry,
      acoustic: acoustic,
      questionnaire: questionnaire,
      riskResult: riskResult,
      clinicalNotes: (map['clinical_notes'] as String?) ?? '',
    );
  }
}
