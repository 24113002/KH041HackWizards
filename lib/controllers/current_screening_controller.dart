import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/patient_model.dart';
import '../models/questionnaire_model.dart';
import '../models/screening_result_model.dart';
import '../models/screening_session_model.dart';
import '../models/sensor_data_model.dart';
import '../models/sensor_reading_model.dart';
import '../models/swaas_ai_ble_result.dart';
import '../repositories/screening_repository.dart';

class CurrentScreeningController extends ChangeNotifier {
  Patient? _patient;
  Patient? get patient => _patient;

  ScreeningSession? _session;
  ScreeningSession? get session => _session;

  SwaasAiBleResult? _bleResult;
  SwaasAiBleResult? get bleResult => _bleResult;

  String? _lastProcessedBleRecordId;
  String? get lastProcessedBleRecordId => _lastProcessedBleRecordId;

  SensorReading? _sensorReading;
  SensorReading? get sensorReading => _sensorReading;

  VitalsReading _vitals = VitalsReading.initial();
  VitalsReading get vitals => _vitals;

  SpirometrySummary _spirometry = SpirometrySummary.empty();
  SpirometrySummary get spirometry => _spirometry;

  AcousticSummary _acoustic = AcousticSummary.empty();
  AcousticSummary get acoustic => _acoustic;

  QuestionnaireResponse _questionnaire = const QuestionnaireResponse();
  QuestionnaireResponse get questionnaire => _questionnaire;

  RiskResult? _riskResult;
  RiskResult? get riskResult => _riskResult;

  bool get isSessionActive => _session != null && _session!.status == ScreeningStatus.inProgress;

  /// Starts a new screening session associated with [patient]
  void startNewSession(Patient patient) {
    _patient = patient;
    final sessionId = const Uuid().v4();
    _session = ScreeningSession(
      id: sessionId,
      patientId: patient.id,
      startedAt: DateTime.now(),
      status: ScreeningStatus.inProgress,
      patient: patient,
    );
    _bleResult = null;
    _lastProcessedBleRecordId = null;
    _sensorReading = SensorReading(
      id: const Uuid().v4(),
      screeningId: sessionId,
      timestamp: DateTime.now(),
      spo2: 97,
      heartRate: null,
      pressure: null,
      coughActivity: null,
    );
    _vitals = VitalsReading(
      heartRate: 0,
      spo2: 97,
      ppgValue: 0.5,
      timestamp: DateTime.now(),
    );
    _spirometry = SpirometrySummary.empty();
    _acoustic = AcousticSummary.empty();
    _questionnaire = QuestionnaireResponse(screeningId: sessionId);
    _riskResult = null;
    notifyListeners();
  }

  /// Ingests a completed SwaasAI ESP32 hardware BLE packet and updates state
  void applyBleResult(SwaasAiBleResult result) {
    _bleResult = result;
    _lastProcessedBleRecordId = result.id;

    if (result.spo2 != null) {
      _vitals = VitalsReading(
        heartRate: 0, // Not in BLE contract; preserve 0/null semantics
        spo2: result.spo2!,
        ppgValue: 0.5,
        timestamp: result.receivedAt,
      );
    }

    _sensorReading = SensorReading(
      id: result.id,
      screeningId: _session?.id ?? 'screening_${result.id}',
      timestamp: result.receivedAt,
      spo2: result.spo2,
      heartRate: null,
      pressure: result.airflow != null ? (result.airflow! / 10000.0) : null,
      coughActivity: result.cough != null ? (result.cough! / 2000.0).clamp(0.0, 1.0) : null,
    );

    // Map hardware risk score & status directly without running conflicting algorithms
    final int score = result.risk ?? 0;
    final String category = result.status.label;
    final riskLevel = _mapStatusToRiskLevel(result.status);

    _riskResult = RiskResult(
      screeningId: _session?.id ?? 'screening_${result.id}',
      riskScore: score,
      riskCategory: category,
      riskLevel: riskLevel,
      spo2: result.spo2 ?? 0,
      heartRate: 0,
      pefLpm: result.airflow != null ? (result.airflow! / 100.0) : 0.0,
      coughCount: result.cough != null ? (result.cough! ~/ 500) : 0,
      contributingFactors: [
        if (result.spo2 != null) 'SpO₂: ${result.spo2}%',
        if (result.airflow != null) 'Raw Airflow Feature: ${result.airflow}',
        if (result.cough != null) 'Cough Signal: ${result.cough}',
        if (result.status == SwaasAiStatus.incomplete) 'One or more measurements unavailable (NA)',
      ],
      recommendation: result.status.displayDescription,
      recommendations: [result.status.displayDescription],
      createdAt: result.receivedAt,
    );

    if (_session != null) {
      _session = _session!.copyWith(
        riskScore: result.risk,
        riskCategory: category,
        riskResult: _riskResult,
        sensorReading: _sensorReading,
        vitals: _vitals,
      );
    }

    notifyListeners();
  }

  static RiskLevel _mapStatusToRiskLevel(SwaasAiStatus status) {
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

  void updateVitals(VitalsReading vitals) {
    _vitals = vitals;
    if (_sensorReading != null) {
      _sensorReading = _sensorReading!.copyWith(
        spo2: vitals.spo2,
        heartRate: vitals.heartRate,
      );
    }
    notifyListeners();
  }

  void updateSpirometry(SpirometrySummary spirometry) {
    _spirometry = spirometry;
    if (_sensorReading != null) {
      _sensorReading = _sensorReading!.copyWith(
        pressure: spirometry.pefLpm > 0 ? (spirometry.pefLpm / 200.0) : null,
      );
    }
    notifyListeners();
  }

  void updateAcoustic(AcousticSummary acoustic) {
    _acoustic = acoustic;
    if (_sensorReading != null) {
      _sensorReading = _sensorReading!.copyWith(
        coughActivity: acoustic.coughCount > 0 ? (acoustic.coughCount * 0.25).clamp(0.0, 1.0) : null,
      );
    }
    notifyListeners();
  }

  void updateQuestionnaire(QuestionnaireResponse questionnaire) {
    _questionnaire = questionnaire.copyWith(screeningId: _session?.id ?? '');
    notifyListeners();
  }

  void updateRiskResult(RiskResult result) {
    _riskResult = result;
    if (_session != null) {
      _session = _session!.copyWith(
        riskScore: result.riskScore,
        riskCategory: result.riskCategory,
        riskResult: result,
      );
    }
    notifyListeners();
  }

  /// Finalizes the current screening session and persists via repository
  Future<bool> completeSession(ScreeningRepository repository, {String clinicalNotes = ''}) async {
    if (_session == null || _patient == null) return false;

    try {
      final finalResult = _riskResult ??
          RiskResult.mock(
            screeningId: _session!.id,
            score: 14,
            category: 'Low Risk',
          );

      final completedSession = _session!.copyWith(
        completedAt: DateTime.now(),
        status: ScreeningStatus.completed,
        riskScore: finalResult.riskScore,
        riskCategory: finalResult.riskCategory,
        patient: _patient,
        sensorReading: _sensorReading,
        vitals: _vitals,
        spirometry: _spirometry,
        acoustic: _acoustic,
        questionnaire: _questionnaire,
        riskResult: finalResult,
        clinicalNotes: clinicalNotes,
      );

      await repository.createScreening(completedSession);
      _session = completedSession;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error completing screening session: $e');
      return false;
    }
  }

  void cancelSession() {
    _patient = null;
    _session = null;
    _bleResult = null;
    _lastProcessedBleRecordId = null;
    _sensorReading = null;
    _riskResult = null;
    notifyListeners();
  }
}
