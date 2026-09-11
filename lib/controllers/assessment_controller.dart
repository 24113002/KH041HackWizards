import 'package:flutter/foundation.dart';
import '../engine/risk_assessment_engine.dart';
import '../models/risk_assessment_input.dart';
import '../models/screening_result_model.dart';
import '../models/swaas_ai_ble_result.dart';
import 'current_screening_controller.dart';

enum AssessmentStatus {
  idle,
  assessing,
  completed,
  error,
  mismatched,
}

class AssessmentController extends ChangeNotifier {
  AssessmentStatus _status = AssessmentStatus.idle;
  AssessmentStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  RiskResult? _riskResult;
  RiskResult? get riskResult => _riskResult;

  RiskAssessmentInput? _assessmentInput;
  RiskAssessmentInput? get assessmentInput => _assessmentInput;

  bool get isAssessing => _status == AssessmentStatus.assessing;
  bool get hasError => _status == AssessmentStatus.error || _status == AssessmentStatus.mismatched;

  void reset() {
    _status = AssessmentStatus.idle;
    _errorMessage = null;
    _riskResult = null;
    _assessmentInput = null;
    notifyListeners();
  }

  /// Evaluates patient, questionnaire, and sensor observations safely.
  ///
  /// Enforces patient data isolation and prevents patient data mixing.
  Future<RiskResult?> runAssessment({
    required RiskAssessmentInput input,
    required CurrentScreeningController currentScreeningController,
  }) async {
    _status = AssessmentStatus.assessing;
    _errorMessage = null;
    _assessmentInput = input;
    notifyListeners();

    try {
      // 1. Critical Patient Safety & Data Isolation Verification
      final currentPatient = currentScreeningController.patient;
      final currentSession = currentScreeningController.session;

      if (currentPatient == null || currentSession == null) {
        _status = AssessmentStatus.error;
        _errorMessage = 'No active screening session found.';
        notifyListeners();
        return null;
      }

      if (input.patient.id != currentPatient.id || input.screeningId != currentSession.id) {
        _status = AssessmentStatus.mismatched;
        _errorMessage = 'Screening data does not match the selected patient.';
        notifyListeners();
        return null;
      }

      // Small async yield to allow UI loading state to render smoothly
      await Future.delayed(const Duration(milliseconds: 350));

      final q = input.questionnaire;
      final ble = input.bleResult;
      final RiskResult evaluatedResult;

      // 2. Risk Assessment Evaluation
      if (ble != null) {
        if (ble.isIncomplete || ble.risk == null) {
          // Incomplete Screening Handling (NA preserved)
          final missingFactors = <String>[];
          if (ble.spo2 == null) missingFactors.add('SpO₂: Not Available (NA)');
          if (ble.airflow == null) missingFactors.add('Raw Airflow Feature: Not Available (NA)');
          if (ble.cough == null) missingFactors.add('Cough Signal: Not Available (NA)');

          evaluatedResult = RiskResult(
            screeningId: input.screeningId,
            riskScore: 0,
            overallScore: 0,
            riskCategory: 'Incomplete',
            riskLevel: RiskLevel.low,
            contributingFactors: [
              ...missingFactors,
              if (q.smokingStatus != 'Non-smoker') 'Smoking history: ${q.smokingStatus}',
              if (q.biomassExposure != 'None') 'Biomass exposure: ${q.biomassExposure}',
              if (q.breathlessness > 0) 'Breathlessness: Grade ${q.breathlessness}',
              if (q.chronicCough) 'Chronic cough reported',
            ],
            recommendation:
                'Screening incomplete. One or more required sensor measurements were unavailable. Please repeat the required measurement or follow clinical protocol.',
            recommendations: const [
              'Screening incomplete. One or more required sensor measurements were unavailable. Please repeat the required measurement or follow clinical protocol.'
            ],
            emergencyFlag: false,
            spo2: 0,
            heartRate: 0,
            createdAt: ble.receivedAt,
          );
        } else {
          // Valid Complete ESP32 Hardware Packet
          final factors = <String>[];
          if (q.smokingStatus != 'Non-smoker') {
            factors.add(q.yearsSmoked > 0
                ? 'Smoking history (${q.smokingStatus.toLowerCase()}, ${q.yearsSmoked.toStringAsFixed(0)} yrs)'
                : 'Smoking history (${q.smokingStatus.toLowerCase()})');
          }
          if (q.biomassExposure == 'High/Daily' || q.biomassExposure == 'Moderate') {
            factors.add('Biomass smoke exposure (${q.biomassExposure.toLowerCase()})');
          }
          if (q.breathlessness >= 2) {
            factors.add('Breathlessness on exertion (mMRC Grade ${q.breathlessness})');
          } else if (q.breathlessness == 1) {
            factors.add('Mild exertion breathlessness (mMRC Grade 1)');
          }
          if (q.chronicCough) factors.add('Chronic cough (> 3 weeks)');
          if (q.phlegm) factors.add('Regular phlegm / sputum production');
          if (q.wheezing) factors.add('Wheezing / chest whistling');
          if (q.recurrentRespiratoryProblems) factors.add('Recurrent respiratory problems');
          if (ble.spo2 != null) factors.add('SpO₂ saturation: ${ble.spo2}%');
          if (ble.airflow != null) factors.add('Raw Airflow Feature: ${ble.airflow}');
          if (ble.cough != null) factors.add('Cough Signal: ${ble.cough}');

          final recs = <String>[];
          recs.add('Clinical evaluation is recommended when appropriate based on the screening result and symptoms.');
          if (q.smokingStatus == 'Current smoker') {
            recs.add('Advise smoking cessation counseling and support.');
          }
          if (q.biomassExposure == 'High/Daily' || q.biomassExposure == 'Moderate') {
            recs.add('Advise minimizing indoor biomass/chulha smoke exposure with improved ventilation.');
          }

          final bool isEmergency = ble.spo2 != null && ble.spo2! < 88;
          if (isEmergency) {
            recs.insert(0, 'URGENT: Low SpO₂ observed. Immediate medical evaluation recommended.');
          }

          evaluatedResult = RiskResult(
            screeningId: input.screeningId,
            riskScore: ble.risk!,
            overallScore: ble.risk!,
            riskCategory: ble.status.label,
            riskLevel: _mapStatusToLevel(ble.status, isEmergency: isEmergency),
            contributingFactors: factors.isNotEmpty ? factors : const ['Normal screening parameters'],
            recommendation: recs.first,
            recommendations: recs,
            emergencyFlag: isEmergency,
            spo2: ble.spo2 ?? 0,
            heartRate: 0,
            createdAt: ble.receivedAt,
          );
        }
      } else {
        // Fallback to local RiskAssessmentEngine if no BLE result
        evaluatedResult = RiskAssessmentEngine.evaluate(
          patient: input.patient,
          vitals: currentScreeningController.vitals,
          spirometry: currentScreeningController.spirometry,
          acoustic: currentScreeningController.acoustic,
          questionnaire: q,
        );
      }

      // 3. Update CurrentScreeningController state
      currentScreeningController.updateQuestionnaire(q);
      currentScreeningController.updateRiskResult(evaluatedResult);

      _riskResult = evaluatedResult;
      _status = AssessmentStatus.completed;
      notifyListeners();
      return evaluatedResult;
    } catch (e) {
      debugPrint('[AssessmentController] Assessment error: $e');
      _status = AssessmentStatus.error;
      _errorMessage = 'Unable to complete the screening assessment. Please try again.';
      notifyListeners();
      return null;
    }
  }

  static RiskLevel _mapStatusToLevel(SwaasAiStatus status, {bool isEmergency = false}) {
    if (isEmergency) return RiskLevel.critical;
    switch (status) {
      case SwaasAiStatus.low:
        return RiskLevel.low;
      case SwaasAiStatus.moderate:
        return RiskLevel.moderate;
      case SwaasAiStatus.high:
        return RiskLevel.high;
      case SwaasAiStatus.incomplete:
      case SwaasAiStatus.unknown:
        return RiskLevel.low;
    }
  }
}
