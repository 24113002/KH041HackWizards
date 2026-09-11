import 'package:flutter/foundation.dart';
import '../models/screening_session_model.dart';
import '../repositories/screening_repository.dart';

enum ScreeningSortOrder {
  newestFirst,
  oldestFirst,
}

class ScreeningHistoryController extends ChangeNotifier {
  final ScreeningRepository repository;

  List<ScreeningSession> _history = [];
  List<ScreeningSession> get history => _history;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  String _filterCategory = 'All';
  String get filterCategory => _filterCategory;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  ScreeningSortOrder _sortOrder = ScreeningSortOrder.newestFirst;
  ScreeningSortOrder get sortOrder => _sortOrder;

  ScreeningHistoryController({required this.repository}) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await repository.getScreenings();
      _history = List<ScreeningSession>.from(results);
      _applySorting();
    } catch (e) {
      _error = 'Unable to load screening records. Please try again.';
      debugPrint('Error loading screening history: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilterCategory(String category) {
    _filterCategory = category;
    notifyListeners();
  }

  void searchHistory(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortOrder(ScreeningSortOrder order) {
    _sortOrder = order;
    _applySorting();
    notifyListeners();
  }

  void toggleSortOrder() {
    _sortOrder = _sortOrder == ScreeningSortOrder.newestFirst
        ? ScreeningSortOrder.oldestFirst
        : ScreeningSortOrder.newestFirst;
    _applySorting();
    notifyListeners();
  }

  void clearFilters() {
    _filterCategory = 'All';
    _searchQuery = '';
    _sortOrder = ScreeningSortOrder.newestFirst;
    _applySorting();
    notifyListeners();
  }

  void _applySorting() {
    if (_sortOrder == ScreeningSortOrder.newestFirst) {
      _history.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    } else {
      _history.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    }
  }

  List<ScreeningSession> get filteredHistory {
    return _history.where((session) {
      // 1. Search Matching (Patient Name, Village, or Screening ID)
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final patientName = session.patient?.fullName.toLowerCase() ?? session.patient?.name.toLowerCase() ?? '';
        final village = session.patient?.village.toLowerCase() ?? '';
        final screeningId = session.id.toLowerCase();
        final recordId = session.sensorReading?.id.toLowerCase() ?? '';

        final matchesSearch = patientName.contains(query) ||
            village.contains(query) ||
            screeningId.contains(query) ||
            recordId.contains(query);

        if (!matchesSearch) return false;
      }

      // 2. Filter Category Matching
      if (_filterCategory == 'All') return true;

      final category = (session.riskCategory ?? session.riskResult.riskCategory).toLowerCase();
      final status = session.status.name.toLowerCase();

      if (_filterCategory == 'Completed') {
        return session.status == ScreeningStatus.completed;
      }
      if (_filterCategory == 'Incomplete') {
        return session.status == ScreeningStatus.incomplete ||
            session.status == ScreeningStatus.cancelled ||
            category.contains('incomplete');
      }
      if (_filterCategory == 'Higher Risk' || _filterCategory == 'High') {
        return category.contains('high') || category.contains('critical');
      }
      if (_filterCategory == 'Moderate Risk' || _filterCategory == 'Moderate') {
        return category.contains('moderate');
      }
      if (_filterCategory == 'Lower Risk' || _filterCategory == 'Low') {
        return category.contains('low') && !category.contains('incomplete');
      }

      return category.contains(_filterCategory.toLowerCase()) || status.contains(_filterCategory.toLowerCase());
    }).toList();
  }

  List<ScreeningSession> getScreeningsForPatient(String patientId) {
    return _history.where((s) => s.patientId == patientId).toList();
  }

  Future<ScreeningSession?> getScreeningDetails(String id) async {
    try {
      return await repository.getScreeningById(id);
    } catch (e) {
      debugPrint('Error fetching screening details: $e');
      return null;
    }
  }

  Future<bool> deleteScreening(String id) async {
    try {
      await repository.deleteScreening(id);
      _history.removeWhere((s) => s.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting screening record: $e');
      return false;
    }
  }
}
