import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/patient_model.dart';
import '../models/questionnaire_model.dart';
import '../models/risk_result_model.dart';
import '../models/screening_session_model.dart';
import '../models/sensor_reading_model.dart';
import 'api_client.dart';

class BackendApiService {
  final ApiClient _client;

  BackendApiService({ApiClient? client}) : _client = client ?? ApiClient();

  /// Health check verifying backend connection
  Future<bool> checkHealth() async {
    try {
      final res = await _client.get(ApiConfig.healthPath);
      return res is Map && (res['status'] == 'healthy' || res['status'] == 'online' || res['status'] == 'ok');
    } catch (e) {
      debugPrint('[BackendApiService] Health check failed: $e');
      return false;
    }
  }

  // ==========================================
  // PATIENT ENDPOINTS
  // ==========================================

  /// Registers a new patient on the backend
  Future<Patient> createPatient(Patient patient) async {
    final response = await _client.post(
      ApiConfig.patientsPath,
      body: patient.toApiJson(),
    );
    return Patient.fromApiJson(
      Map<String, dynamic>.from(response as Map),
      localId: patient.id,
    );
  }

  /// Retrieves all registered patients from the backend
  Future<List<Patient>> getPatients({int skip = 0, int limit = 100}) async {
    final response = await _client.get(
      ApiConfig.patientsPath,
      queryParameters: {'skip': skip, 'limit': limit},
    );
    if (response is List) {
      return response
          .map((item) => Patient.fromApiJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    return [];
  }

  /// Searches patients by name
  Future<List<Patient>> searchPatients(String query) async {
    final response = await _client.get(
      '${ApiConfig.patientsPath}/search',
      queryParameters: {'q': query},
    );
    if (response is List) {
      return response
          .map((item) => Patient.fromApiJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    return [];
  }

  /// Gets patient details by backend integer ID
  Future<Patient?> getPatient(int backendId) async {
    try {
      final response = await _client.get('${ApiConfig.patientsPath}/$backendId');
      return Patient.fromApiJson(Map<String, dynamic>.from(response as Map));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Updates patient details on the backend
  Future<Patient> updatePatient(int backendId, Patient patient) async {
    final response = await _client.put(
      '${ApiConfig.patientsPath}/$backendId',
      body: patient.toApiJson(),
    );
    return Patient.fromApiJson(
      Map<String, dynamic>.from(response as Map),
      localId: patient.id,
    );
  }

  /// Deletes patient record on the backend
  Future<void> deletePatient(int backendId) async {
    await _client.delete('${ApiConfig.patientsPath}/$backendId');
  }

  // ==========================================
  // SCREENING ENDPOINTS
  // ==========================================

  /// Starts a new screening session on the backend
  Future<ScreeningSession> startScreening({
    required int patientBackendId,
    String? localScreeningId,
    String? localPatientId,
  }) async {
    final response = await _client.post(
      ApiConfig.screeningsPath,
      body: {'patient_id': patientBackendId},
    );
    return ScreeningSession.fromApiJson(
      Map<String, dynamic>.from(response as Map),
      localId: localScreeningId,
      localPatientId: localPatientId,
    );
  }

  /// Retrieves screening session details
  Future<ScreeningSession?> getScreening(int screeningBackendId) async {
    try {
      final response = await _client.get('${ApiConfig.screeningsPath}/$screeningBackendId');
      return ScreeningSession.fromApiJson(Map<String, dynamic>.from(response as Map));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Completes a screening session and triggers the ML Late-Fusion assessment
  Future<ScreeningSession> completeScreening(int screeningBackendId, {String? localScreeningId}) async {
    final response = await _client.post('${ApiConfig.screeningsPath}/$screeningBackendId/complete');
    return ScreeningSession.fromApiJson(
      Map<String, dynamic>.from(response as Map),
      localId: localScreeningId,
    );
  }

  /// Retrieves the evaluated Risk Result from the backend
  Future<RiskResult> getRiskResult(int screeningBackendId, {String? localScreeningId}) async {
    final response = await _client.get('${ApiConfig.screeningsPath}/$screeningBackendId/risk-result');
    return RiskResult.fromApiJson(
      Map<String, dynamic>.from(response as Map),
      localScreeningId: localScreeningId,
    );
  }

  // ==========================================
  // QUESTIONNAIRE ENDPOINTS
  // ==========================================

  /// Submits questionnaire responses for a screening session
  Future<QuestionnaireResponse> submitQuestionnaire(
    int screeningBackendId,
    QuestionnaireResponse questionnaire,
  ) async {
    final response = await _client.post(
      '${ApiConfig.screeningsPath}/$screeningBackendId/questionnaire',
      body: questionnaire.toApiJson(),
    );
    return QuestionnaireResponse.fromApiJson(
      Map<String, dynamic>.from(response as Map),
      localScreeningId: questionnaire.screeningId,
    );
  }

  // ==========================================
  // SENSOR ENDPOINTS
  // ==========================================

  /// Records a single sensor reading
  Future<SensorReading> submitSensorReading(
    int screeningBackendId,
    SensorReading reading,
  ) async {
    final response = await _client.post(
      '${ApiConfig.screeningsPath}/$screeningBackendId/sensor-data',
      body: reading.toApiJson(),
    );
    return SensorReading.fromApiJson(
      Map<String, dynamic>.from(response as Map),
      localScreeningId: reading.screeningId,
    );
  }

  /// Bulk submits continuous sensor readings
  Future<List<SensorReading>> submitBulkSensorReadings(
    int screeningBackendId,
    List<SensorReading> readings,
  ) async {
    if (readings.isEmpty) return [];
    final response = await _client.post(
      '${ApiConfig.screeningsPath}/$screeningBackendId/sensor-data/bulk',
      body: {
        'readings': readings.map((r) => r.toApiJson()).toList(),
      },
    );
    if (response is List) {
      return response
          .map((item) => SensorReading.fromApiJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    return [];
  }
}
