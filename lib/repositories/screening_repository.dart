import '../data/database_helper.dart';
import '../models/screening_session_model.dart';

abstract class ScreeningRepository {
  Future<void> createScreening(ScreeningSession screening);
  Future<void> updateScreening(ScreeningSession screening);
  Future<List<ScreeningSession>> getScreenings();
  Future<ScreeningSession?> getScreeningById(String id);
  Future<List<ScreeningSession>> getScreeningsForPatient(String patientId);
  Future<void> deleteScreening(String id);
}

class LocalScreeningRepository implements ScreeningRepository {
  final DatabaseHelper _dbHelper;

  LocalScreeningRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<void> createScreening(ScreeningSession screening) async {
    await _dbHelper.insertScreening(screening);
  }

  @override
  Future<void> updateScreening(ScreeningSession screening) async {
    await _dbHelper.updateScreening(screening);
  }

  @override
  Future<List<ScreeningSession>> getScreenings() async {
    return await _dbHelper.getAllScreenings();
  }

  @override
  Future<ScreeningSession?> getScreeningById(String id) async {
    return await _dbHelper.getScreeningById(id);
  }

  @override
  Future<List<ScreeningSession>> getScreeningsForPatient(String patientId) async {
    return await _dbHelper.getScreeningsForPatient(patientId);
  }

  @override
  Future<void> deleteScreening(String id) async {
    await _dbHelper.deleteScreening(id);
  }
}
