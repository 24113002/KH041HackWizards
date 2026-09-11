import 'package:flutter/foundation.dart';
import '../models/patient_model.dart';
import '../repositories/patient_repository.dart';

class PatientProvider extends ChangeNotifier {
  final PatientRepository repository;

  List<Patient> _patients = [];
  List<Patient> get patients => _patients;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  Patient? _selectedPatient;
  Patient? get selectedPatient => _selectedPatient;

  PatientProvider({required this.repository}) {
    loadPatients();
  }

  Future<void> loadPatients() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_searchQuery.trim().isEmpty) {
        _patients = await repository.getPatients();
      } else {
        _patients = await repository.searchPatients(_searchQuery);
      }
    } catch (e) {
      _error = 'Unable to load patient records. Please try again.';
      debugPrint('PatientProvider error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void searchPatients(String query) {
    _searchQuery = query;
    loadPatients();
  }

  void selectPatient(Patient? patient) {
    _selectedPatient = patient;
    notifyListeners();
  }

  Future<bool> createPatient(Patient patient) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await repository.createPatient(patient);
      _selectedPatient = patient;
      await loadPatients();
      return true;
    } catch (e) {
      _error = 'Unable to save patient. Please try again.';
      debugPrint('Error creating patient: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePatient(Patient patient) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await repository.updatePatient(patient);
      if (_selectedPatient?.id == patient.id) {
        _selectedPatient = patient;
      }
      await loadPatients();
      return true;
    } catch (e) {
      _error = 'Unable to update patient. Please try again.';
      debugPrint('Error updating patient: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePatient(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await repository.deletePatient(id);
      if (_selectedPatient?.id == id) {
        _selectedPatient = null;
      }
      await loadPatients();
      return true;
    } catch (e) {
      _error = 'Unable to delete patient.';
      debugPrint('Error deleting patient: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
