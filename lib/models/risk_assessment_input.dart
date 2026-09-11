import 'patient_model.dart';
import 'questionnaire_model.dart';
import 'swaas_ai_ble_result.dart';

/// Clean input data model required for offline respiratory risk assessment.
///
/// Combines validated patient demographic context, completed clinical questionnaire,
/// and received hardware sensor observations.
class RiskAssessmentInput {
  final String screeningId;
  final Patient patient;
  final QuestionnaireResponse questionnaire;
  final SwaasAiBleResult? bleResult;
  final DateTime createdAt;

  RiskAssessmentInput({
    required this.screeningId,
    required this.patient,
    required this.questionnaire,
    this.bleResult,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Validates that all IDs and associations belong strictly to the same screening session
  bool get isDataConsistent {
    if (patient.id.isEmpty || screeningId.isEmpty) return false;
    if (questionnaire.screeningId.isNotEmpty && questionnaire.screeningId != screeningId) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> toMap() {
    return {
      'screening_id': screeningId,
      'patient_id': patient.id,
      'patient_age': patient.age,
      'patient_gender': patient.gender.name,
      'questionnaire': questionnaire.toMap(),
      'ble_result': bleResult?.toMap(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
