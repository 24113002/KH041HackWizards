import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:swasthai/config/api_config.dart';
import 'package:swasthai/controllers/assessment_controller.dart';
import 'package:swasthai/controllers/current_screening_controller.dart';
import 'package:swasthai/data/database_helper.dart';
import 'package:swasthai/models/patient_model.dart';
import 'package:swasthai/models/questionnaire_model.dart';
import 'package:swasthai/models/risk_assessment_input.dart';
import 'package:swasthai/models/screening_session_model.dart';
import 'package:swasthai/models/swaas_ai_ble_result.dart';
import 'package:swasthai/repositories/sync_repository.dart';
import 'package:swasthai/services/api_client.dart';
import 'package:swasthai/services/backend_api_service.dart';
import 'package:swasthai/services/swaas_ai_packet_parser.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    ApiConfig.baseUrl = 'http://127.0.0.1:8000/api';
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
  });

  group('Phase 18: End-to-End Integration & Screening Lifecycle', () {
    test('Complete 25-step end-to-end workflow: Online ML Fusion & Offline Fallback', () async {
      // 1. Setup Mock Backend supporting full screening flow
      bool backendOnline = true;
      int backendPatientCounter = 100;
      int backendScreeningCounter = 500;

      final mockHttp = MockClient((request) async {
        if (!backendOnline) {
          throw http.ClientException('Backend is offline');
        }

        final path = request.url.path;

        // Health endpoint
        if (path.endsWith('/health')) {
          return http.Response(jsonEncode({'status': 'ok'}), 200, headers: {'content-type': 'application/json'});
        }

        // POST /patients
        if (request.method == 'POST' && path.endsWith('/patients')) {
          backendPatientCounter++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': backendPatientCounter,
              'full_name': body['full_name'],
              'age': body['age'],
              'gender': body['gender'],
              'village': body['village'],
              'occupation': body['occupation'],
              'smoking_status': body['smoking_status'],
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        // POST /screenings
        if (request.method == 'POST' && path.endsWith('/screenings')) {
          backendScreeningCounter++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': backendScreeningCounter,
              'patient_id': body['patient_id'],
              'started_at': DateTime.now().toIso8601String(),
              'status': 'in_progress',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        // POST /screenings/{id}/questionnaire
        if (request.method == 'POST' && path.contains('/questionnaire')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': 1,
              'screening_id': backendScreeningCounter,
              ...body,
              'created_at': DateTime.now().toIso8601String(),
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        // POST /screenings/{id}/sensor-data
        if (request.method == 'POST' && path.contains('/sensor-data')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': 1,
              'screening_id': backendScreeningCounter,
              ...body,
              'timestamp': DateTime.now().toIso8601String(),
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        // POST /screenings/{id}/complete
        if (request.method == 'POST' && path.contains('/complete')) {
          return http.Response(
            jsonEncode({
              'id': backendScreeningCounter,
              'patient_id': backendPatientCounter,
              'started_at': DateTime.now().toIso8601String(),
              'completed_at': DateTime.now().toIso8601String(),
              'status': 'completed',
              'risk_score': 68.0,
              'risk_category': 'Moderate Risk',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // GET /screenings/{id}/risk-result
        if (request.method == 'GET' && path.contains('/risk-result')) {
          return http.Response(
            jsonEncode({
              'id': 1,
              'screening_id': backendScreeningCounter,
              'risk_score': 68.0,
              'risk_category': 'Moderate Risk',
              'contributing_factors': ['Biomass smoke exposure', 'Elevated cough activity'],
              'recommendation': 'Clinical Evaluation Recommended. Consider spirometry follow-up.',
              'created_at': DateTime.now().toIso8601String(),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(httpClient: mockHttp);
      final apiService = BackendApiService(client: apiClient);
      final syncRepo = SyncRepository(apiService: apiService);
      final screeningCtrl = CurrentScreeningController();
      final assessmentCtrl = AssessmentController(apiService: apiService);

      // STEP 1-4: Create Patient and verify local SQLite persistence + backend sync
      final patient = Patient(
        id: 'patient-e2e-1',
        fullName: 'Kisan Baburao Hazare',
        age: 65,
        gender: Gender.male,
        village: 'Ralegan Siddhi',
        occupation: 'Social Activist',
        smokingStatus: 'Non-smoker',
      );
      await syncRepo.createPatient(patient);

      final localPatient = await syncRepo.getPatientById('patient-e2e-1');
      expect(localPatient, isNotNull);
      expect(localPatient!.fullName, equals('Kisan Baburao Hazare'));
      expect(localPatient.backendId, equals(101));

      // STEP 5-6: Start Screening Session
      screeningCtrl.startNewSession(localPatient);
      expect(screeningCtrl.isSessionActive, isTrue);
      expect(screeningCtrl.session!.patientId, equals('patient-e2e-1'));

      // STEP 7-10: Ingest BLE Hardware Packet
      const blePacket = 'R01,42350,97,1860,42,MODERATE';
      final bleResult = SwaasAiPacketParser.parse(blePacket);
      expect(bleResult.spo2, equals(97));
      expect(bleResult.airflow, equals(42350));
      expect(bleResult.cough, equals(1860));
      expect(bleResult.risk, equals(42));
      expect(bleResult.status, equals(SwaasAiStatus.moderate));
      expect(bleResult.formattedStatus, equals('MODERATE'));

      screeningCtrl.applyBleResult(bleResult);
      expect(screeningCtrl.sensorReading, isNotNull);
      expect(screeningCtrl.sensorReading!.spo2, equals(97));

      // STEP 11-12: Questionnaire Submission
      final questionnaire = QuestionnaireResponse(
        screeningId: screeningCtrl.session!.id,
        smokingStatus: 'Non-smoker',
        biomassExposure: 'High/Daily',
        breathlessness: 2,
        chronicCough: true,
        phlegm: false,
        wheezing: true,
        recurrentRespiratoryProblems: true,
      );
      screeningCtrl.updateQuestionnaire(questionnaire);

      // STEP 13-16: Run Authoritative Backend ML Assessment
      final input = RiskAssessmentInput(
        patient: localPatient,
        screeningId: screeningCtrl.session!.id,
        questionnaire: questionnaire,
        bleResult: bleResult,
      );

      final evaluatedRisk = await assessmentCtrl.runAssessment(
        input: input,
        currentScreeningController: screeningCtrl,
      );

      expect(evaluatedRisk, isNotNull);
      expect(evaluatedRisk!.riskScore, equals(68));
      expect(evaluatedRisk.riskCategory, equals('Moderate Risk'));
      expect(evaluatedRisk.contributingFactors.length, equals(2));
      expect(evaluatedRisk.recommendation, contains('Clinical Evaluation Recommended'));

      // STEP 17-20: Finalize session and store in SQLite
      final completeOk = await screeningCtrl.completeSession(syncRepo);
      expect(completeOk, isTrue);

      final savedScreenings = await syncRepo.getScreeningsForPatient('patient-e2e-1');
      expect(savedScreenings.isNotEmpty, isTrue);
      expect(savedScreenings.first.riskCategory, equals('Moderate Risk'));

      // STEP 21-23: Turn Backend OFF and verify 100% offline screening functionality
      backendOnline = false;

      final offlinePatient = Patient(
        id: 'patient-offline-e2e',
        fullName: 'Gangubai Kathiawadi',
        age: 48,
        gender: Gender.female,
        village: 'Kamathipura',
      );
      await syncRepo.createPatient(offlinePatient);

      final savedOfflineP = await syncRepo.getPatientById('patient-offline-e2e');
      expect(savedOfflineP, isNotNull);
      expect(savedOfflineP!.backendId, isNull); // Offline; backend ID is null

      // Start offline screening
      screeningCtrl.startNewSession(savedOfflineP);
      const incompleteBlePacket = 'R02,39120,NA,1735,NA,INCOMPLETE';
      final incBle = SwaasAiPacketParser.parse(incompleteBlePacket);
      expect(incBle.isIncomplete, isTrue);
      expect(incBle.spo2, isNull);

      screeningCtrl.applyBleResult(incBle);

      final offlineInput = RiskAssessmentInput(
        patient: savedOfflineP,
        screeningId: screeningCtrl.session!.id,
        questionnaire: const QuestionnaireResponse(),
        bleResult: incBle,
      );

      final offlineResult = await assessmentCtrl.runAssessment(
        input: offlineInput,
        currentScreeningController: screeningCtrl,
      );

      expect(offlineResult, isNotNull);
      expect(offlineResult!.riskCategory, equals('Incomplete'));
      expect(offlineResult.contributingFactors.any((f) => f.contains('SpO₂: Not Available (NA)')), isTrue);

      final offlineComplete = await screeningCtrl.completeSession(syncRepo);
      expect(offlineComplete, isTrue);

      // STEP 24-25: Turn Backend ON and verify sync of pending records
      backendOnline = true;
      await syncRepo.syncAllPendingRecords();

      final recheckedOfflineP = await syncRepo.getPatientById('patient-offline-e2e');
      expect(recheckedOfflineP!.backendId, isNotNull); // Successfully synchronized
    });
  });
}
