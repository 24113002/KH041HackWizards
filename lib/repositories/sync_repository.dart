import 'package:flutter/foundation.dart';
import '../data/database_helper.dart';
import '../models/patient_model.dart';
import '../models/screening_session_model.dart';
import '../services/backend_api_service.dart';
import 'patient_repository.dart';
import 'screening_repository.dart';

/// Hybrid Offline-First Sync Repository bridging local SQLite with FastAPI backend
class SyncRepository implements PatientRepository, ScreeningRepository {
  final DatabaseHelper _dbHelper;
  final BackendApiService _apiService;
  final LocalPatientRepository _localPatientRepo;
  final LocalScreeningRepository _localScreeningRepo;

  SyncRepository({
    DatabaseHelper? dbHelper,
    BackendApiService? apiService,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _apiService = apiService ?? BackendApiService(),
        _localPatientRepo = LocalPatientRepository(dbHelper: dbHelper ?? DatabaseHelper.instance),
        _localScreeningRepo = LocalScreeningRepository(dbHelper: dbHelper ?? DatabaseHelper.instance);

  BackendApiService get apiService => _apiService;

  // ==========================================
  // PATIENT OPERATIONS (Offline-First)
  // ==========================================

  @override
  Future<List<Patient>> getPatients() async {
    return await _localPatientRepo.getPatients();
  }

  @override
  Future<Patient?> getPatientById(String id) async {
    return await _localPatientRepo.getPatientById(id);
  }

  @override
  Future<void> createPatient(Patient patient) async {
    // 1. Always save locally first (guaranteed offline persistence)
    await _localPatientRepo.createPatient(patient);

    // 2. Opportunistic background sync to FastAPI backend
    try {
      final isOnline = await _apiService.checkHealth();
      if (isOnline) {
        final synced = await _apiService.createPatient(patient);
        if (synced.backendId != null) {
          await _dbHelper.updatePatientBackendId(patient.id, synced.backendId!);
          debugPrint('[SyncRepository] Patient ${patient.id} synchronized to backend ID: ${synced.backendId}');
        }
      }
    } catch (e) {
      debugPrint('[SyncRepository] Background patient sync deferred (offline): $e');
    }
  }

  @override
  Future<void> updatePatient(Patient patient) async {
    await _localPatientRepo.updatePatient(patient);

    try {
      if (patient.backendId != null) {
        final isOnline = await _apiService.checkHealth();
        if (isOnline) {
          await _apiService.updatePatient(patient.backendId!, patient);
          debugPrint('[SyncRepository] Patient ${patient.backendId} updated on backend.');
        }
      }
    } catch (e) {
      debugPrint('[SyncRepository] Background patient update deferred (offline): $e');
    }
  }

  @override
  Future<void> deletePatient(String id) async {
    final patient = await _dbHelper.getPatient(id);
    await _localPatientRepo.deletePatient(id);

    try {
      if (patient?.backendId != null) {
        final isOnline = await _apiService.checkHealth();
        if (isOnline) {
          await _apiService.deletePatient(patient!.backendId!);
          debugPrint('[SyncRepository] Patient ${patient.backendId} deleted from backend.');
        }
      }
    } catch (e) {
      debugPrint('[SyncRepository] Background patient deletion deferred: $e');
    }
  }

  @override
  Future<List<Patient>> searchPatients(String query) async {
    return await _localPatientRepo.searchPatients(query);
  }

  // ==========================================
  // SCREENING OPERATIONS (Offline-First)
  // ==========================================

  @override
  Future<void> createScreening(ScreeningSession screening) async {
    // 1. Save locally first
    await _localScreeningRepo.createScreening(screening);

    // 2. Opportunistic backend sync
    await syncScreeningSession(screening);
  }

  @override
  Future<void> updateScreening(ScreeningSession screening) async {
    await _localScreeningRepo.updateScreening(screening);
    await syncScreeningSession(screening);
  }

  @override
  Future<List<ScreeningSession>> getScreenings() async {
    return await _localScreeningRepo.getScreenings();
  }

  @override
  Future<ScreeningSession?> getScreeningById(String id) async {
    return await _localScreeningRepo.getScreeningById(id);
  }

  @override
  Future<List<ScreeningSession>> getScreeningsForPatient(String patientId) async {
    return await _localScreeningRepo.getScreeningsForPatient(patientId);
  }

  @override
  Future<void> deleteScreening(String id) async {
    await _localScreeningRepo.deleteScreening(id);
  }

  /// Synchronizes a screening session, its patient, questionnaire, and sensor readings to FastAPI
  Future<void> syncScreeningSession(ScreeningSession screening) async {
    try {
      final isOnline = await _apiService.checkHealth();
      if (!isOnline) return;

      // Ensure patient is synced first to get patient backend ID
      int? patientBId = screening.patientBackendId;
      if (patientBId == null) {
        final patient = await _dbHelper.getPatient(screening.patientId);
        if (patient != null) {
          if (patient.backendId != null) {
            patientBId = patient.backendId;
          } else {
            final syncedPatient = await _apiService.createPatient(patient);
            if (syncedPatient.backendId != null) {
              patientBId = syncedPatient.backendId;
              await _dbHelper.updatePatientBackendId(patient.id, patientBId!);
            }
          }
        }
      }

      if (patientBId == null) {
        debugPrint('[SyncRepository] Cannot sync screening without valid patientBackendId');
        return;
      }

      // Start screening on backend if not already started
      int? screeningBId = screening.backendId;
      if (screeningBId == null) {
        final syncedScreening = await _apiService.startScreening(
          patientBackendId: patientBId,
          localScreeningId: screening.id,
          localPatientId: screening.patientId,
        );
        screeningBId = syncedScreening.backendId;
        if (screeningBId != null) {
          await _dbHelper.updateScreeningBackendId(screening.id, screeningBId);
          debugPrint('[SyncRepository] Screening ${screening.id} registered on backend ID: $screeningBId');
        }
      }

      if (screeningBId == null) return;

      // Sync Questionnaire
      if (screening.questionnaire.screeningId.isNotEmpty || screening.questionnaire.symptomScore > 0) {
        try {
          await _apiService.submitQuestionnaire(screeningBId, screening.questionnaire);
          debugPrint('[SyncRepository] Questionnaire synced for backend screening $screeningBId');
        } catch (qe) {
          debugPrint('[SyncRepository] Questionnaire sync notice: $qe');
        }
      }

      // Sync Sensor Reading
      if (screening.sensorReading != null) {
        try {
          await _apiService.submitSensorReading(screeningBId, screening.sensorReading!);
          debugPrint('[SyncRepository] Sensor reading synced for backend screening $screeningBId');
        } catch (se) {
          debugPrint('[SyncRepository] Sensor sync notice: $se');
        }
      }

      // Complete screening and trigger backend ML assessment if completed
      if (screening.status == ScreeningStatus.completed) {
        try {
          await _apiService.completeScreening(screeningBId, localScreeningId: screening.id);
          debugPrint('[SyncRepository] Screening $screeningBId completed on backend with ML Late-Fusion');
        } catch (ce) {
          debugPrint('[SyncRepository] Screening completion notice: $ce');
        }
      }
    } catch (e) {
      debugPrint('[SyncRepository] Screening session sync deferred (offline): $e');
    }
  }

  /// Bulk syncs all un-synced local records when internet connectivity is re-established
  Future<void> syncAllPendingRecords() async {
    try {
      final isOnline = await _apiService.checkHealth();
      if (!isOnline) {
        debugPrint('[SyncRepository] Backend offline. Pending sync skipped.');
        return;
      }

      debugPrint('[SyncRepository] Starting pending records synchronization...');
      final allPatients = await _dbHelper.getAllPatients();
      for (final p in allPatients) {
        if (p.backendId == null) {
          try {
            final synced = await _apiService.createPatient(p);
            if (synced.backendId != null) {
              await _dbHelper.updatePatientBackendId(p.id, synced.backendId!);
            }
          } catch (e) {
            debugPrint('[SyncRepository] Patient sync failed for ${p.id}: $e');
          }
        }
      }

      final allScreenings = await _dbHelper.getAllScreenings();
      for (final s in allScreenings) {
        if (s.backendId == null) {
          await syncScreeningSession(s);
        }
      }
      debugPrint('[SyncRepository] Pending records synchronization completed.');
    } catch (e) {
      debugPrint('[SyncRepository] Error during full synchronization: $e');
    }
  }
}
