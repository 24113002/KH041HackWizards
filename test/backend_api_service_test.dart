import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swasthai/config/api_config.dart';
import 'package:swasthai/models/patient_model.dart';
import 'package:swasthai/models/questionnaire_model.dart';
import 'package:swasthai/models/sensor_reading_model.dart';
import 'package:swasthai/services/api_client.dart';
import 'package:swasthai/services/backend_api_service.dart';

void main() {
  setUp(() {
    ApiConfig.baseUrl = 'http://127.0.0.1:8000/api/v1';
  });

  group('BackendApiService Endpoint Integration', () {
    test('checkHealth returns true when backend is healthy', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/health')) {
          return http.Response(jsonEncode({'status': 'healthy'}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final service = BackendApiService(client: ApiClient(httpClient: mockClient));
      final isHealthy = await service.checkHealth();
      expect(isHealthy, isTrue);
    });

    test('createPatient issues POST /patients and deserializes response', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/patients')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['full_name'], equals('Rahul Patil'));
          return http.Response(
            jsonEncode({
              'id': 10,
              'full_name': 'Rahul Patil',
              'age': 52,
              'gender': 'male',
              'village': 'Khed',
              'occupation': 'Farmer',
              'smoking_status': 'Current smoker',
              'created_at': '2026-09-12T04:00:00',
              'updated_at': '2026-09-12T04:00:00',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = BackendApiService(client: ApiClient(httpClient: mockClient));
      final patient = Patient(
        id: 'local-uuid-1',
        fullName: 'Rahul Patil',
        age: 52,
        gender: Gender.male,
        village: 'Khed',
        occupation: 'Farmer',
        smokingStatus: 'Current smoker',
      );

      final result = await service.createPatient(patient);
      expect(result.id, equals('local-uuid-1'));
      expect(result.backendId, equals(10));
      expect(result.fullName, equals('Rahul Patil'));
    });

    test('startScreening issues POST /screenings and creates backend session', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/screenings')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['patient_id'], equals(10));
          return http.Response(
            jsonEncode({
              'id': 25,
              'patient_id': 10,
              'started_at': '2026-09-12T04:00:00',
              'status': 'in_progress',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = BackendApiService(client: ApiClient(httpClient: mockClient));
      final screening = await service.startScreening(
        patientBackendId: 10,
        localScreeningId: 'local-screen-1',
        localPatientId: 'local-patient-1',
      );

      expect(screening.id, equals('local-screen-1'));
      expect(screening.backendId, equals(25));
      expect(screening.patientBackendId, equals(10));
    });

    test('completeScreening and fetchRiskResult return evaluated risk output', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/screenings/25/complete')) {
          return http.Response(
            jsonEncode({
              'id': 25,
              'patient_id': 10,
              'started_at': '2026-09-12T04:00:00',
              'completed_at': '2026-09-12T04:05:00',
              'status': 'completed',
              'risk_score': 72.0,
              'risk_category': 'Higher Risk',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && request.url.path.endsWith('/screenings/25/risk-result')) {
          return http.Response(
            jsonEncode({
              'id': 1,
              'screening_id': 25,
              'risk_score': 72.0,
              'risk_category': 'Higher Risk',
              'contributing_factors': ['SpO2 Saturation < 90%', 'Prolonged Biomass Smoke Exposure'],
              'recommendation': 'Clinical Evaluation Recommended. Refer for comprehensive spirometry assessment.',
              'created_at': '2026-09-12T04:05:00',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = BackendApiService(client: ApiClient(httpClient: mockClient));
      final completed = await service.completeScreening(25, localScreeningId: 'local-screen-1');
      expect(completed.backendId, equals(25));
      expect(completed.riskCategory, equals('Higher Risk'));

      final risk = await service.getRiskResult(25, localScreeningId: 'local-screen-1');
      expect(risk.riskScore, equals(72));
      expect(risk.riskCategory, equals('Higher Risk'));
      expect(risk.contributingFactors.length, equals(2));
    });
  });
}
