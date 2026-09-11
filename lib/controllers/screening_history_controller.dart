import 'package:flutter/foundation.dart';
import '../models/screening_session_model.dart';
import '../repositories/screening_repository.dart';

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

  ScreeningHistoryController({required this.repository}) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _history = await repository.getScreenings();
      // Sort newest first
      _history.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    } catch (e) {
      _error = 'Unable to load screening records. Please try again.';
      debugPrint('Error loading screening history: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void filterByCategory(String category) {
    _filterCategory = category;
    notifyListeners();
  }

  void searchHistory(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<ScreeningSession> get filteredHistory {
    return _history.where((session) {
      final patientName = session.patient?.fullName.toLowerCase() ?? session.patient?.name.toLowerCase() ?? '';
      final matchesSearch = patientName.contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      if (_filterCategory == 'All') return true;
      final cat = session.riskCategory?.toLowerCase() ?? session.riskResult.riskCategory.toLowerCase();
      return cat.contains(_filterCategory.toLowerCase());
    }).toList();
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
