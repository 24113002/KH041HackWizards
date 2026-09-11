import 'package:flutter_test/flutter_test.dart';
import 'package:swasthai/controllers/assessment_controller.dart';
import 'package:swasthai/controllers/current_screening_controller.dart';
import 'package:swasthai/controllers/questionnaire_controller.dart';
import 'package:swasthai/models/patient_model.dart';
import 'package:swasthai/models/questionnaire_model.dart';
import 'package:swasthai/models/risk_assessment_input.dart';
import 'package:swasthai/models/screening_session_model.dart';
import 'package:swasthai/models/swaas_ai_ble_result.dart';
import 'package:swasthai/repositories/screening_repository.dart';
import 'package:swasthai/services/swaas_ai_packet_parser.dart';

class InMemoryScreeningRepository implements ScreeningRepository {
  final List<ScreeningSession> sessions = [];

  @override
  Future<void> createScreening(ScreeningSession session) async {
    final existingIdx = sessions.indexWhere((s) => s.id == session.id);
    if (existingIdx != -1) {
      sessions[existingIdx] = session; // Prevent duplicates by ID
    } else {
      sessions.add(session);
    }
  }

  @override
  Future<void> updateScreening(ScreeningSession session) async {
    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      sessions[index] = session;
    } else {
      sessions.add(session);
    }
  }

  @override
  Future<List<ScreeningSession>> getScreenings() async {
    return List.unmodifiable(sessions);
  }

  @override
  Future<List<ScreeningSession>> getScreeningsForPatient(String patientId) async {
    return sessions.where((s) => s.patientId == patientId).toList();
  }

  @override
  Future<ScreeningSession?> getScreeningById(String id) async {
    return sessions.where((s) => s.id == id).firstOrNull;
  }

  @override
  Future<void> deleteScreening(String id) async {
    sessions.removeWhere((s) => s.id == id);
  }
}

void main() {
  group('Phase 5 — Questionnaire, Risk Assessment & Result Experience Tests', () {
    late Patient testPatientRahul;
    late Patient testPatientAnita;
    late InMemoryScreeningRepository repository;
    late CurrentScreeningController screeningController;
    late QuestionnaireController questionnaireController;
    late AssessmentController assessmentController;

    setUp(() {
      testPatientRahul = Patient(
        id: 'patient_rahul_001',
        name: 'Rahul Patil',
        age: 52,
        gender: Gender.male,
        village: 'Khed Shivapur',
        heightCm: 170.0,
        weightKg: 68.0,
      );

      testPatientAnita = Patient(
        id: 'patient_anita_002',
        name: 'Anita Deshmukh',
        age: 48,
        gender: Gender.female,
        village: 'Saswad',
        heightCm: 156.0,
        weightKg: 54.0,
      );

      repository = InMemoryScreeningRepository();
      screeningController = CurrentScreeningController();
      questionnaireController = QuestionnaireController();
      assessmentController = AssessmentController();
    });

    // -------------------------------------------------------------
    // 1. Questionnaire Validation Tests
    // -------------------------------------------------------------
    test('1. Validates complete questionnaire responses for former smoker', () {
      questionnaireController.setSmokingStatus('Former smoker');
      questionnaireController.setYearsSmoked(25);
      questionnaireController.setCigarettesPerDay(10);
      questionnaireController.setBiomassExposure('High/Daily');
      questionnaireController.setBreathlessness(2);
      questionnaireController.setChronicCough(true);
      questionnaireController.setPhlegm(false);
      questionnaireController.setWheezing(true);
      questionnaireController.setRecurrentRespiratoryProblems(false);

      expect(questionnaireController.isValid, isTrue);
      expect(questionnaireController.validate(), isNull);

      final response = questionnaireController.toResponse();
      expect(response.smokingStatus, equals('Former smoker'));
      expect(response.yearsSmoked, equals(25.0));
      expect(response.cigarettesPerDay, equals(10));
      expect(response.biomassExposure, equals('High/Daily'));
      expect(response.breathlessness, equals(2));
      expect(response.chronicCough, isTrue);
      expect(response.phlegm, isFalse);
      expect(response.wheezing, isTrue);
      expect(response.recurrentRespiratoryProblems, isFalse);
      expect(response.packYears, equals(12.5)); // (25 * 10) / 20
    });

    test('2. Rejects invalid questionnaire when smoker details are missing', () {
      questionnaireController.setSmokingStatus('Current smoker');
      questionnaireController.setYearsSmoked(0); // Missing years smoked
      questionnaireController.setCigarettesPerDay(0);

      expect(questionnaireController.isValid, isFalse);
      expect(questionnaireController.validate(), contains('years smoked'));
    });

    test('3. Non-smokers do not require years smoked or cigarettes per day', () {
      questionnaireController.setSmokingStatus('Non-smoker');
      questionnaireController.setBiomassExposure('None');
      questionnaireController.setBreathlessness(0);
      questionnaireController.setChronicCough(false);
      questionnaireController.setPhlegm(false);
      questionnaireController.setWheezing(false);
      questionnaireController.setRecurrentRespiratoryProblems(false);

      expect(questionnaireController.isValid, isTrue);
      expect(questionnaireController.yearsSmoked, equals(0.0));
      expect(questionnaireController.cigarettesPerDay, equals(0));
    });

    // -------------------------------------------------------------
    // 2. Risk Assessment & End-to-End Workflow (Section 38 Prompt Test)
    // -------------------------------------------------------------
    test('4. End-to-End Test with Rahul Patil and valid packet R01,42350,97,1860,42,MODERATE', () async {
      // Step 1: Start screening for Rahul
      screeningController.startNewSession(testPatientRahul);
      final sessionId = screeningController.session!.id;
      expect(sessionId, isNotEmpty);

      // Step 2: Receive sensor result from ESP32
      final bleResult = SwaasAiPacketParser.parse('R01,42350,97,1860,42,MODERATE');
      screeningController.applyBleResult(bleResult);

      expect(screeningController.bleResult, equals(bleResult));
      expect(screeningController.bleResult!.airflow, equals(42350));
      expect(screeningController.bleResult!.spo2, equals(97));
      expect(screeningController.bleResult!.cough, equals(1860));
      expect(screeningController.bleResult!.risk, equals(42));
      expect(screeningController.bleResult!.status, equals(SwaasAiStatus.moderate));

      // Step 3: Complete questionnaire
      questionnaireController.initializeWithResponse(
        const QuestionnaireResponse(
          smokingStatus: 'Former smoker',
          yearsSmoked: 25.0,
          cigarettesPerDay: 10,
          biomassExposure: 'High/Daily',
          breathlessness: 2,
          chronicCough: true,
          phlegm: false,
          wheezing: true,
          recurrentRespiratoryProblems: false,
        ),
        screeningId: sessionId,
      );

      final qResponse = questionnaireController.toResponse();

      // Step 4: Run Risk Assessment
      final input = RiskAssessmentInput(
        screeningId: sessionId,
        patient: testPatientRahul,
        questionnaire: qResponse,
        bleResult: bleResult,
      );

      final assessmentResult = await assessmentController.runAssessment(
        input: input,
        currentScreeningController: screeningController,
      );

      expect(assessmentResult, isNotNull);
      expect(assessmentResult!.riskScore, equals(42));
      expect(assessmentResult.riskCategory, equals('Moderate Risk'));
      expect(assessmentResult.contributingFactors, contains(contains('Smoking history')));
      expect(assessmentResult.contributingFactors, contains(contains('Biomass smoke exposure')));
      expect(assessmentResult.contributingFactors, contains(contains('Breathlessness')));
      expect(assessmentResult.contributingFactors, contains(contains('Chronic cough')));
      expect(assessmentResult.recommendations.first, contains('Clinical evaluation is recommended'));

      // Step 5: Save screening to repository
      final savedSuccess = await screeningController.completeSession(repository, clinicalNotes: 'Follow-up in 2 weeks.');
      expect(savedSuccess, isTrue);

      // Step 6: Verify in repository / history
      final history = await repository.getScreenings();
      expect(history.length, equals(1));
      final savedRecord = history.first;
      expect(savedRecord.id, equals(sessionId)); // Screening ID consistency
      expect(savedRecord.patientId, equals(testPatientRahul.id));
      expect(savedRecord.riskScore, equals(42));
      expect(savedRecord.riskCategory, equals('Moderate Risk'));
      expect(savedRecord.clinicalNotes, equals('Follow-up in 2 weeks.'));
    });

    // -------------------------------------------------------------
    // 3. Incomplete Result Test (Section 39 Prompt Test)
    // -------------------------------------------------------------
    test('5. Incomplete Test with R02,39120,NA,1735,NA,INCOMPLETE preserves NA without fake score', () async {
      screeningController.startNewSession(testPatientRahul);
      final sessionId = screeningController.session!.id;

      final incompleteBleResult = SwaasAiPacketParser.parse('R02,39120,NA,1735,NA,INCOMPLETE');
      screeningController.applyBleResult(incompleteBleResult);

      expect(incompleteBleResult.isIncomplete, isTrue);
      expect(incompleteBleResult.spo2, isNull);
      expect(incompleteBleResult.risk, isNull);
      expect(incompleteBleResult.formattedSpo2, equals('--'));
      expect(incompleteBleResult.formattedRisk, equals('--'));

      final qResponse = const QuestionnaireResponse(
        smokingStatus: 'Non-smoker',
        biomassExposure: 'None',
        breathlessness: 0,
      );

      final input = RiskAssessmentInput(
        screeningId: sessionId,
        patient: testPatientRahul,
        questionnaire: qResponse,
        bleResult: incompleteBleResult,
      );

      final result = await assessmentController.runAssessment(
        input: input,
        currentScreeningController: screeningController,
      );

      expect(result, isNotNull);
      expect(result!.riskCategory, equals('Incomplete'));
      expect(result.contributingFactors, contains(contains('SpO₂: Not Available (NA)')));
      expect(result.recommendation, contains('Screening incomplete'));
    });

    // -------------------------------------------------------------
    // 4. Duplicate Result Prevention Test (Section 40 Prompt Test)
    // -------------------------------------------------------------
    test('6. Duplicate result does not duplicate database records', () async {
      screeningController.startNewSession(testPatientRahul);

      final bleResult = SwaasAiPacketParser.parse('R01,42350,97,1860,42,MODERATE');
      screeningController.applyBleResult(bleResult);

      await screeningController.completeSession(repository);
      expect((await repository.getScreenings()).length, equals(1));

      // Re-applying and re-completing same session
      screeningController.applyBleResult(bleResult);
      await screeningController.completeSession(repository);

      // Length must remain 1
      expect((await repository.getScreenings()).length, equals(1));
    });

    // -------------------------------------------------------------
    // 5. Patient Data Isolation & Safety Test (Section 41 Prompt Test)
    // -------------------------------------------------------------
    test('7. Patient safety check rejects mismatched patient / session IDs', () async {
      // Start session for Patient Rahul
      screeningController.startNewSession(testPatientRahul);

      // Attempt to run assessment with Patient Anita's data
      final mismatchedInput = RiskAssessmentInput(
        screeningId: 'mismatched_session_999',
        patient: testPatientAnita, // Patient B
        questionnaire: const QuestionnaireResponse(),
      );

      final result = await assessmentController.runAssessment(
        input: mismatchedInput,
        currentScreeningController: screeningController,
      );

      expect(result, isNull);
      expect(assessmentController.status, equals(AssessmentStatus.mismatched));
      expect(assessmentController.errorMessage, equals('Screening data does not match the selected patient.'));
    });

    // -------------------------------------------------------------
    // 6. Complete Session State Transitions
    // -------------------------------------------------------------
    test('8. Session lifecycle transitions from inProgress to completed properly', () async {
      expect(screeningController.isSessionActive, isFalse);

      screeningController.startNewSession(testPatientRahul);
      expect(screeningController.isSessionActive, isTrue);
      expect(screeningController.session!.status, equals(ScreeningStatus.inProgress));

      final bleResult = SwaasAiPacketParser.parse('R01,42350,97,1860,42,MODERATE');
      screeningController.applyBleResult(bleResult);

      final success = await screeningController.completeSession(repository);
      expect(success, isTrue);
      expect(screeningController.session!.status, equals(ScreeningStatus.completed));
    });
  });
}
