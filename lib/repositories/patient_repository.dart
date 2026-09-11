import '../data/database_helper.dart';
import '../models/patient_model.dart';

abstract class PatientRepository {
  Future<List<Patient>> getPatients();
  Future<Patient?> getPatientById(String id);
  Future<void> createPatient(Patient patient);
  Future<void> updatePatient(Patient patient);
  Future<void> deletePatient(String id);
  Future<List<Patient>> searchPatients(String query);
}

class LocalPatientRepository implements PatientRepository {
  final DatabaseHelper _dbHelper;

  LocalPatientRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<List<Patient>> getPatients() async {
    await _ensureDemoPatients();
    return await _dbHelper.getAllPatients();
  }

  @override
  Future<Patient?> getPatientById(String id) async {
    return await _dbHelper.getPatient(id);
  }

  @override
  Future<void> createPatient(Patient patient) async {
    await _dbHelper.insertPatient(patient);
  }

  @override
  Future<void> updatePatient(Patient patient) async {
    await _dbHelper.updatePatient(patient);
  }

  @override
  Future<void> deletePatient(String id) async {
    await _dbHelper.deletePatient(id);
  }

  @override
  Future<List<Patient>> searchPatients(String query) async {
    if (query.trim().isEmpty) {
      return getPatients();
    }
    return await _dbHelper.searchPatients(query.trim());
  }

  /// Seeds demo patients if the local database is empty
  Future<void> _ensureDemoPatients() async {
    final existing = await _dbHelper.getAllPatients();
    if (existing.isEmpty) {
      final demoPatients = [
        Patient(
          id: 'demo-patient-1',
          fullName: 'Rahul Patil',
          age: 52,
          gender: Gender.male,
          village: 'Khed',
          occupation: 'Farmer',
          smokingStatus: 'Current smoker',
          heightCm: 170.0,
          weightKg: 68.0,
          medicalHistory: 'Exertional dyspnea, chronic morning cough',
        ),
        Patient(
          id: 'demo-patient-2',
          fullName: 'Anita Sharma',
          age: 46,
          gender: Gender.female,
          village: 'Shirur',
          occupation: 'Homemaker',
          smokingStatus: 'Non-smoker',
          heightCm: 156.0,
          weightKg: 58.0,
          medicalHistory: 'Biomass chulha smoke exposure for 20 yrs',
        ),
        Patient(
          id: 'demo-patient-3',
          fullName: 'Vijay More',
          age: 61,
          gender: Gender.male,
          village: 'Baramati',
          occupation: 'Retired Mill Worker',
          smokingStatus: 'Former smoker',
          heightCm: 168.0,
          weightKg: 72.0,
          medicalHistory: 'History of asthma, seasonal wheezing',
        ),
      ];

      for (final p in demoPatients) {
        await _dbHelper.insertPatient(p);
      }
    }
  }
}
