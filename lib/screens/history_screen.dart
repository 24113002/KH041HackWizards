import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../controllers/screening_history_controller.dart';
import '../models/screening_session_model.dart';
import '../theme/app_theme.dart';
import 'screening_details_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ScreeningHistoryController>().loadHistory();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getRiskColor(String category, ScreeningStatus status) {
    if (status == ScreeningStatus.incomplete || category.toLowerCase().contains('incomplete')) {
      return AppTheme.riskModerate;
    }
    final lower = category.toLowerCase();
    if (lower.contains('critical') || lower.contains('urgent') || lower.contains('high')) {
      return lower.contains('critical') ? AppTheme.riskCritical : AppTheme.riskHigh;
    }
    if (lower.contains('moderate')) {
      return AppTheme.riskModerate;
    }
    return AppTheme.riskLow;
  }

  String _getCategoryDisplay(String category, ScreeningStatus status) {
    if (status == ScreeningStatus.incomplete || category.toLowerCase().contains('incomplete')) {
      return 'INCOMPLETE';
    }
    final lower = category.toLowerCase();
    if (lower.contains('high') || lower.contains('critical')) return 'HIGHER RISK';
    if (lower.contains('moderate')) return 'MODERATE RISK';
    if (lower.contains('low')) return 'LOWER RISK';
    return category.toUpperCase();
  }

  Future<void> _confirmDeleteScreening(ScreeningSession session) async {
    final patientName = session.patient?.fullName ?? session.patient?.name ?? 'Patient';
    final screeningId = session.sensorReading?.id.isNotEmpty == true ? session.sensorReading!.id : session.id;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppTheme.riskCritical),
            SizedBox(width: 10),
            Text('Delete Screening Record?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete screening ($screeningId) for $patientName?',
              style: const TextStyle(color: AppTheme.textLight, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 10),
            const Text(
              '• Patient profile will remain safe.\n• Only this screening session will be removed from local storage.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.riskCritical),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await context.read<ScreeningHistoryController>().deleteScreening(session.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Screening record deleted.' : 'Failed to delete screening record.'),
            backgroundColor: success ? AppTheme.surfaceElevated : AppTheme.riskCritical,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyCtrl = context.watch<ScreeningHistoryController>();
    final list = historyCtrl.filteredHistory;
    final isSearching = historyCtrl.searchQuery.isNotEmpty || historyCtrl.filterCategory != 'All';

    const filterOptions = ['All', 'Completed', 'Incomplete', 'Higher Risk', 'Moderate Risk', 'Lower Risk'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screening History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(
              historyCtrl.sortOrder == ScreeningSortOrder.newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
              color: AppTheme.primaryTeal,
              size: 20,
            ),
            tooltip: historyCtrl.sortOrder == ScreeningSortOrder.newestFirst ? 'Sort: Newest First' : 'Sort: Oldest First',
            onPressed: historyCtrl.toggleSortOrder,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh History',
            onPressed: historyCtrl.loadHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Offline Storage Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppTheme.primaryTeal.withAlpha(18),
            child: const Row(
              children: [
                Icon(Icons.offline_pin_outlined, size: 14, color: AppTheme.primaryTeal),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Offline Mode Active • Local SQLite Database (No Internet Required)',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          // 2. Search Box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by patient name, village, or screening ID...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: AppTheme.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          historyCtrl.searchHistory('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: historyCtrl.searchHistory,
            ),
          ),

          // 3. Filter Chips Carousel
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: filterOptions.map((filter) {
                final isSelected = (historyCtrl.filterCategory == filter);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryTeal.withAlpha(60),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textMuted,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => historyCtrl.setFilterCategory(filter),
                  ),
                );
              }).toList(),
            ),
          ),

          // 4. Header stats & Active Filters row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${list.length} ${list.length == 1 ? 'record' : 'records'} found',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                ),
                if (isSearching)
                  TextButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      historyCtrl.clearFilters();
                    },
                    icon: const Icon(Icons.filter_alt_off, size: 14, color: AppTheme.primaryTeal),
                    label: const Text('Clear Filters', style: TextStyle(fontSize: 11, color: AppTheme.primaryTeal)),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF334155), height: 1),

          // 5. Screenings List
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.primaryTeal,
              onRefresh: historyCtrl.loadHistory,
              child: historyCtrl.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
                  : list.isEmpty
                      ? _buildEmptyState(isSearching, historyCtrl)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          itemCount: list.length,
                          itemBuilder: (ctx, idx) {
                            final session = list[idx];
                            return _buildScreeningCard(session);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreeningCard(ScreeningSession session) {
    final p = session.patient;
    final r = session.riskResult;
    final status = session.status;
    final category = session.riskCategory ?? r.riskCategory;
    final color = _getRiskColor(category, status);
    final categoryLabel = _getCategoryDisplay(category, status);
    final dateFormatted = DateFormat('dd MMM yyyy • hh:mm a').format(session.startedAt);

    final recordId = session.sensorReading?.id.isNotEmpty == true
        ? session.sensorReading!.id
        : (session.id.length > 8 ? session.id.substring(0, 8) : session.id);

    final scoreDisplay = (status == ScreeningStatus.incomplete || category.toLowerCase().contains('incomplete'))
        ? '--'
        : '${session.riskScore ?? r.riskScore} / 100';

    final spo2Display = session.vitals.spo2 > 0 ? '${session.vitals.spo2}%' : '--';
    final airflowDisplay = session.sensorReading?.pressure != null
        ? '${(session.sensorReading!.pressure! * 10000).toInt()}'
        : '--';
    final coughDisplay = session.sensorReading?.coughActivity != null
        ? '${(session.sensorReading!.coughActivity! * 2000).toInt()}'
        : (session.acoustic.coughCount > 0 ? '${session.acoustic.coughCount}' : '--');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ScreeningDetailsScreen(session: session),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Patient Info & Risk Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: color.withAlpha(30),
                    child: Text(
                      p?.name.isNotEmpty == true ? p!.name[0].toUpperCase() : 'P',
                      style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p?.fullName ?? p?.name ?? 'Unknown Patient',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textLight),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${p?.age ?? '--'} yrs • ${p?.gender.name.toUpperCase() ?? '--'} • ID: $recordId',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withAlpha(35),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withAlpha(90)),
                        ),
                        child: Text(
                          categoryLabel,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Score: $scoreDisplay',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: Color(0xFF334155), height: 18),

              // Sensor Observations Line (SpO2, Airflow Feature, Cough Signal)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetricPill(label: 'SpO₂', value: spo2Display, icon: Icons.bloodtype, color: AppTheme.primaryTeal),
                  _buildMetricPill(label: 'Airflow', value: airflowDisplay, icon: Icons.air, color: AppTheme.primaryBlue),
                  _buildMetricPill(label: 'Cough', value: coughDisplay, icon: Icons.graphic_eq, color: AppTheme.accentIndigo),
                  _buildMetricPill(label: 'Status', value: status.label, icon: Icons.check_circle_outline, color: AppTheme.textMuted),
                ],
              ),
              const SizedBox(height: 8),

              // Footer: Date and Action Icons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 12, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        dateFormatted,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textMuted),
                        tooltip: 'Delete Record',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _confirmDeleteScreening(session),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.textMuted),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricPill({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: const TextStyle(fontSize: 10, color: AppTheme.textLight, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isSearching, ScreeningHistoryController ctrl) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearching ? Icons.search_off : Icons.history_edu,
                size: 44,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'No matching screenings found.' : 'No screenings recorded yet.',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textLight),
            ),
            const SizedBox(height: 6),
            Text(
              isSearching
                  ? 'Try adjusting your search query or clear the active risk/status filters.'
                  : 'Screenings saved through ESP32 testing or questionnaires will appear here offline.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 16),
            if (isSearching)
              ElevatedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  ctrl.clearFilters();
                },
                icon: const Icon(Icons.filter_alt_off, size: 16),
                label: const Text('Clear Filters'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
              ),
          ],
        ),
      ),
    );
  }
}
