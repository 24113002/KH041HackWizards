import 'dart:convert';
import 'patient_model.dart';
import 'questionnaire_model.dart';
import 'risk_result_model.dart' if (dart.library.io) 'screening_result_model.dart'; // import screening_result_model.dart
import 'sensor_reading_model.dart';
import 'sensor_data_model.dart';

enum ScreeningStatus {
  inProgress,
  completed,
  cancelled,
}

extension ScreeningStatusExtension on ScreeningStatus {
  String get label {
    switch (this) {
      case ScreeningStatus.inProgress:
        return 'In Progress';
      case ScreeningStatus.completed:
        return 'Completed';
      case ScreeningStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class ScreeningSession {
  final String id;
  final String patientId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final ScreeningStatus status;
  final int? riskScore;
  final String? riskCategory;

  // Attached sub-models
  final Patient? patient;
  final SensorReading? sensorReading;
  final VitalsReading vitals;
  final SpirometrySummary spirometry;
  final AcousticSummary acoustic;
  final QuestionnaireResponse questionnaire;
  final RiskResult riskResult;
  final String clinicalNotes;

  ScreeningSession({
    required this.id,
    required this.patientId,
    DateTime? startedAt,
    DateTime? timestamp,
    this.completedAt,
    this.status = ScreeningStatus.inProgress,
    this.riskScore,
    this.riskCategory,
    this.patient,
    this.sensorReading,
    VitalsReading? vitals,
    SpirometrySummary? spirometry,
    AcousticSummary? acoustic,
    QuestionnaireResponse? questionnaire,
    RiskResult? riskResult,
    this.clinicalNotes = '',
  })  : startedAt = startedAt ?? timestamp ?? DateTime.now(),
        vitals = vitals ?? VitalsReading.initial(),
        spirometry = spirometry ?? SpirometrySummary.empty(),
        acoustic = acoustic ?? AcousticSummary.empty(),
        questionnaire = questionnaire ?? const QuestionnaireResponse(),
        riskResult = riskResult ??
            RiskResult.mock(
              screeningId: id,
              score: riskScore ?? 12,
              category: riskCategory ?? 'Low Risk',
            );

  DateTime get timestamp => startedAt;

  ScreeningSession copyWith({
    String? id,
    String? patientId,
    DateTime? startedAt,
    DateTime? timestamp,
    DateTime? completedAt,
    ScreeningStatus? status,
    int? riskScore,
    String? riskCategory,
    Patient? patient,
    SensorReading? sensorReading,
    VitalsReading? vitals,
    SpirometrySummary? spirometry,
    AcousticSummary? acoustic,
    QuestionnaireResponse? questionnaire,
    RiskResult? riskResult,
    String? clinicalNotes,
  }) {
    return ScreeningSession(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      startedAt: startedAt ?? timestamp ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      riskScore: riskScore ?? this.riskScore,
      riskCategory: riskCategory ?? this.riskCategory,
      patient: patient ?? this.patient,
      sensorReading: sensorReading ?? this.sensorReading,
      vitals: vitals ?? this.vitals,
      spirometry: spirometry ?? this.spirometry,
      acoustic: acoustic ?? this.acoustic,
      questionnaire: questionnaire ?? this.questionnaire,
      riskResult: riskResult ?? this.riskResult,
      clinicalNotes: clinicalNotes ?? this.clinicalNotes,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'status': status.name,
      'timestamp': startedAt.toIso8601String(),
      'heart_rate': vitals.heartRate,
      'spo2': vitals.spo2,
      'fev1': spirometry.fev1,
      'fvc': spirometry.fvc,
      'fev1_fvc_ratio': spirometry.fev1FvcRatio,
      'pef_lpm': spirometry.pefLpm,
      'cough_count': acoustic.coughCount,
      'symptom_score': questionnaire.symptomScore,
      'risk_level': (riskCategory ?? riskResult.riskCategory).toLowerCase(),
      'risk_score': riskScore ?? riskResult.riskScore,
      'risk_category': riskCategory ?? riskResult.riskCategory,
      'clinical_pattern': riskResult.clinicalPattern.name,
      'clinical_notes': clinicalNotes,
      'full_payload_json': jsonEncode({
        'sensor_reading': sensorReading?.toMap(),
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

    final sensorReading = payload['sensor_reading'] != null
        ? SensorReading.fromMap(Map<String, dynamic>.from(payload['sensor_reading'] as Map))
        : null;

    final vitals = payload['vitals'] != null
        ? VitalsReading.fromMap(Map<String, dynamic>.from(payload['vitals'] as Map))
        : VitalsReading(
            heartRate: (map['heart_rate'] as num?)?.toInt() ?? 75,
            spo2: (map['spo2'] as num?)?.toInt() ?? 98,
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
            screeningId: map['id'] as String,
            riskScore: (map['risk_score'] as num?)?.toInt() ?? 0,
            riskCategory: (map['risk_category'] as String?) ?? (map['risk_level'] as String?) ?? 'Low Risk',
          );

    final statusStr = (map['status'] as String?) ?? 'completed';
    final status = ScreeningStatus.values.firstWhere(
      (s) => s.name.toLowerCase() == statusStr.toLowerCase(),
      orElse: () => ScreeningStatus.completed,
    );

    return ScreeningSession(
      id: map['id'] as String,
      patientId: map['patient_id'] as String,
      startedAt: DateTime.tryParse(map['started_at'] as String? ?? map['timestamp'] as String? ?? '') ?? DateTime.now(),
      completedAt: DateTime.tryParse(map['completed_at'] as String? ?? ''),
      status: status,
      riskScore: (map['risk_score'] as num?)?.toInt(),
      riskCategory: map['risk_category'] as String?,
      patient: attachedPatient,
      sensorReading: sensorReading,
      vitals: vitals,
      spirometry: spirometry,
      acoustic: acoustic,
      questionnaire: questionnaire,
      riskResult: riskResult,
      clinicalNotes: (map['clinical_notes'] as String?) ?? '',
    );
  }
}
