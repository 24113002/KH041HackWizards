import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/patient_provider.dart';
import '../theme/app_theme.dart';
import 'add_edit_patient_screen.dart';
import 'patient_details_screen.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddPatient() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditPatientScreen()),
    ).then((_) {
      if (mounted) {
        context.read<PatientProvider>().loadPatients();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PatientProvider>();
    final patients = provider.patients;
    final isLoading = provider.isLoading;
    final error = provider.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Directory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textLight),
            onPressed: () => provider.loadPatients(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.surfaceElevated,
            child: const Row(
              children: [
                Icon(Icons.wifi_off_outlined, size: 14, color: AppTheme.primaryTeal),
                SizedBox(width: 8),
                Text(
                  'OFFLINE MODE: Local data is stored on this device.',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, village, or occupation...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: AppTheme.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          provider.searchPatients('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (val) => provider.searchPatients(val),
            ),
          ),

          // Body List / States
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
                : error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 40, color: AppTheme.riskCritical),
                            const SizedBox(height: 10),
                            Text(error, style: const TextStyle(color: AppTheme.textMuted)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => provider.loadPatients(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : patients.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline, size: 54, color: AppTheme.textMuted.withAlpha(80)),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No patients registered yet',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Tap "+ Add Patient" to register a patient and start screening.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    onPressed: _openAddPatient,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add First Patient'),
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            itemCount: patients.length,
                            itemBuilder: (ctx, idx) {
                              final p = patients[idx];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(12),
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.primaryTeal.withAlpha(35),
                                    child: Text(
                                      p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : 'P',
                                      style: const TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(
                                    p.fullName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textLight),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      '${p.age} yrs • ${p.gender.name.toUpperCase()} • ${p.village.isNotEmpty ? p.village : 'Village N/A'} • ${p.smokingStatus}',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PatientDetailsScreen(patient: p),
                                      ),
                                    ).then((_) => provider.loadPatients());
                                  },
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddPatient,
        backgroundColor: AppTheme.primaryTeal,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Patient', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
