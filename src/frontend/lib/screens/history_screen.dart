import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/database_helper.dart';
import '../models/screening_result_model.dart';
import '../models/screening_session_model.dart';
import '../theme/app_theme.dart';
import 'screening_result_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ScreeningSession> _screenings = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final list = await DatabaseHelper.instance.getAllScreenings();
    setState(() {
      _screenings = list;
      _isLoading = false;
    });
  }

  List<ScreeningSession> get _filteredList {
    return _screenings.where((s) {
      final name = s.patient?.name.toLowerCase() ?? '';
      final matchesSearch = name.contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Low') return s.riskResult.riskLevel == RiskLevel.low;
      if (_selectedFilter == 'Moderate') return s.riskResult.riskLevel == RiskLevel.moderate;
      if (_selectedFilter == 'High') return s.riskResult.riskLevel == RiskLevel.high;
      if (_selectedFilter == 'Critical') return s.riskResult.riskLevel == RiskLevel.critical;
      return true;
    }).toList();
  }

  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return AppTheme.riskLow;
      case RiskLevel.moderate:
        return AppTheme.riskModerate;
      case RiskLevel.high:
        return AppTheme.riskHigh;
      case RiskLevel.critical:
        return AppTheme.riskCritical;
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredList;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Screening Records', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Column(
        children: [
          // Search & Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search patient name...',
                prefixIcon: Icon(Icons.search, color: AppTheme.textMuted),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: ['All', 'Low', 'Moderate', 'High', 'Critical'].map((f) {
                final isSelected = (_selectedFilter == f);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryTeal.withAlpha(60),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textMuted,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() => _selectedFilter = f),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(color: Color(0xFF334155), height: 16),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
                : list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_edu, size: 48, color: AppTheme.textMuted.withAlpha(80)),
                            const SizedBox(height: 12),
                            const Text('No screening records found', style: TextStyle(color: AppTheme.textMuted)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: list.length,
                        itemBuilder: (ctx, idx) {
                          final s = list[idx];
                          final p = s.patient;
                          final r = s.riskResult;
                          final color = _getRiskColor(r.riskLevel);
                          final dateFormatted = DateFormat('dd MMM yyyy, HH:mm').format(s.timestamp);

                          return Dismissible(
                            key: Key(s.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: AppTheme.riskCritical,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) async {
                              await DatabaseHelper.instance.deleteScreening(s.id);
                              _screenings.removeWhere((item) => item.id == s.id);
                            },
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(14),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: color.withAlpha(30),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: color.withAlpha(90)),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${r.overallScore}',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
                                    ),
                                  ),
                                ),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        p?.name ?? 'Unknown Patient',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textLight),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withAlpha(40),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        r.riskLevel.shortLabel.toUpperCase(),
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      r.clinicalPattern.displayName,
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'SpO2: ${s.vitals.spo2}% • HR: ${s.vitals.heartRate} bpm • FEV1/FVC: ${(s.spirometry.fev1FvcRatio * 100).toStringAsFixed(0)}% • $dateFormatted',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                                onTap: () {
                                  if (p != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ScreeningResultScreen(
                                          patient: p,
                                          vitals: s.vitals,
                                          spirometry: s.spirometry,
                                          acoustic: s.acoustic,
                                          questionnaire: s.questionnaire,
                                          riskResult: s.riskResult,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
