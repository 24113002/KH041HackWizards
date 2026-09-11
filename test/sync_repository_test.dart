import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:swasthai/config/api_config.dart';
import 'package:swasthai/data/database_helper.dart';
import 'package:swasthai/models/patient_model.dart';
import 'package:swasthai/models/screening_session_model.dart';
import 'package:swasthai/repositories/sync_repository.dart';
import 'package:swasthai/services/api_client.dart';
import 'package:swasthai/services/backend_api_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
  });

  group('SyncRepository Offline-First & Hybrid Sync', () {
    test('createPatient persists to SQLite even when backend is offline', () async {
      // Mock client that simulates network connection failure
      final offlineClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final syncRepo = SyncRepository(
        apiService: BackendApiService(client: ApiClient(httpClient: offlineClient)),
      );

      final patient = Patient(
        id: 'patient-offline-test-1',
        fullName: 'Eknath Shinde',
        age: 60,
        gender: Gender.male,
        village: 'Thane',
        occupation: 'Service',
      );

      // Should save to local SQLite without throwing exception
      await syncRepo.createPatient(patient);

      final saved = await syncRepo.getPatientById('patient-offline-test-1');
      expect(saved, isNotNull);
      expect(saved!.fullName, equals('Eknath Shinde'));
      expect(saved.backendId, isNull); // Backend was offline
    });

    test('createPatient synchronizes backend ID when backend is online', () async {
      final onlineClient = MockClient((request) async {
        if (request.url.path.endsWith('/health')) {
          return http.Response(jsonEncode({'status': 'healthy'}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.method == 'POST' && request.url.path.endsWith('/patients')) {
          return http.Response(
            jsonEncode({
              'id': 88,
              'full_name': 'Devendra Fadnavis',
              'age': 54,
              'gender': 'male',
              'village': 'Nagpur',
              'occupation': 'Public Service',
              'smoking_status': 'Non-smoker',
              'created_at': '2026-09-12T04:00:00',
              'updated_at': '2026-09-12T04:00:00',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final syncRepo = SyncRepository(
        apiService: BackendApiService(client: ApiClient(httpClient: onlineClient)),
      );

      final patient = Patient(
        id: 'patient-online-test-2',
        fullName: 'Devendra Fadnavis',
        age: 54,
        gender: Gender.male,
        village: 'Nagpur',
        occupation: 'Public Service',
      );

      await syncRepo.createPatient(patient);

      final saved = await syncRepo.getPatientById('patient-online-test-2');
      expect(saved, isNotNull);
      expect(saved!.fullName, equals('Devendra Fadnavis'));
      expect(saved.backendId, equals(88)); // Backend ID populated
    });
  });
}
