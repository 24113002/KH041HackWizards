import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/patient_model.dart';
import '../models/questionnaire_model.dart';
import '../models/screening_result_model.dart';
import '../models/screening_session_model.dart';
import '../models/sensor_data_model.dart';
import '../models/sensor_reading_model.dart';
import '../repositories/screening_repository.dart';

class CurrentScreeningController extends ChangeNotifier {
  Patient? _patient;
  Patient? get patient => _patient;

  ScreeningSession? _session;
  ScreeningSession? get session => _session;

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
    _sensorReading = SensorReading(
      id: const Uuid().v4(),
      screeningId: sessionId,
      timestamp: DateTime.now(),
      spo2: 97,
      heartRate: 82,
      pressure: 1.84,
      coughActivity: 0.72,
    );
    _vitals = VitalsReading(
      heartRate: 82,
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
        pressure: spirometry.pefLpm > 0 ? (spirometry.pefLpm / 200.0) : 1.84,
      );
    }
    notifyListeners();
  }

  void updateAcoustic(AcousticSummary acoustic) {
    _acoustic = acoustic;
    if (_sensorReading != null) {
      _sensorReading = _sensorReading!.copyWith(
        coughActivity: acoustic.coughCount > 0 ? (acoustic.coughCount * 0.25).clamp(0.0, 1.0) : 0.0,
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
    _sensorReading = null;
    _riskResult = null;
    notifyListeners();
  }
}
