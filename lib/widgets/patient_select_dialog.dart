import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/database_helper.dart';
import '../models/patient_model.dart';
import '../theme/app_theme.dart';

class PatientSelectDialog extends StatefulWidget {
  const PatientSelectDialog({super.key});

  @override
  State<PatientSelectDialog> createState() => _PatientSelectDialogState();
}

class _PatientSelectDialogState extends State<PatientSelectDialog> {
  List<Patient> _patients = [];
  bool _isLoading = true;
  bool _showCreateForm = false;

  // New Patient Form Controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController(text: '45');
  final _heightController = TextEditingController(text: '168');
  final _weightController = TextEditingController(text: '68');
  final _phoneController = TextEditingController();
  final _historyController = TextEditingController();
  Gender _selectedGender = Gender.male;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);
    final list = await DatabaseHelper.instance.getAllPatients();
    setState(() {
      _patients = list;
      _isLoading = false;
      if (_patients.isEmpty) {
        _showCreateForm = true;
      }
    });
  }

  Future<void> _saveNewPatient() async {
    if (!_formKey.currentState!.validate()) return;

    final newPatient = Patient(
      id: const Uuid().v4(),
      fullName: _nameController.text.trim(),
      age: int.tryParse(_ageController.text) ?? 40,
      gender: _selectedGender,
      heightCm: double.tryParse(_heightController.text) ?? 165.0,
      weightKg: double.tryParse(_weightController.text) ?? 65.0,
      phone: _phoneController.text.trim(),
      medicalHistory: _historyController.text.trim(),
      createdAt: DateTime.now(),
    );

    await DatabaseHelper.instance.insertPatient(newPatient);
    if (mounted) {
      Navigator.pop(context, newPatient);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline, color: AppTheme.primaryTeal),
                    const SizedBox(width: 10),
                    Text(
                      _showCreateForm ? 'Register Patient' : 'Select Patient',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textLight,
                      ),
                    ),
                  ],
                ),
                if (_patients.isNotEmpty)
                  TextButton.icon(
                    icon: Icon(_showCreateForm ? Icons.list : Icons.person_add, size: 16),
                    label: Text(_showCreateForm ? 'Select Existing' : 'New Patient'),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.primaryTeal),
                    onPressed: () {
                      setState(() => _showCreateForm = !_showCreateForm);
                    },
                  ),
              ],
            ),
            const Divider(color: Color(0xFF334155), height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
                  : _showCreateForm
                      ? _buildPatientForm()
                      : _buildPatientList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientList() {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: _patients.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final p = _patients[idx];
              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withAlpha(10)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryTeal.withAlpha(30),
                    child: Text(
                      p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textLight),
                  ),
                  subtitle: Text(
                    '${p.age} yrs • ${p.gender.name.toUpperCase()} • ${p.heightCm.toStringAsFixed(0)} cm • Pred FEV1: ${p.predictedFev1.toStringAsFixed(2)} L',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                  onTap: () => Navigator.pop(context, p),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPatientForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.badge_outlined)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter patient name' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age *', prefixIcon: Icon(Icons.cake_outlined)),
                    validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Valid age required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<Gender>(
                    initialValue: _selectedGender,
                    decoration: const InputDecoration(labelText: 'Biological Sex *'),
                    dropdownColor: AppTheme.surfaceElevated,
                    items: const [
                      DropdownMenuItem(value: Gender.male, child: Text('Male')),
                      DropdownMenuItem(value: Gender.female, child: Text('Female')),
                      DropdownMenuItem(value: Gender.other, child: Text('Other')),
                    ],
                    onChanged: (g) {
                      if (g != null) setState(() => _selectedGender = g);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Height (cm) *', prefixIcon: Icon(Icons.height)),
                    validator: (v) => (double.tryParse(v ?? '') ?? 0) < 50 ? 'Valid height required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Weight (kg) *', prefixIcon: Icon(Icons.monitor_weight_outlined)),
                    validator: (v) => (double.tryParse(v ?? '') ?? 0) < 10 ? 'Valid weight required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Contact / Phone', prefixIcon: Icon(Icons.phone_outlined)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _historyController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Known Medical History',
                hintText: 'e.g. Asthma, Hypertension, Smoker for 10 yrs',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveNewPatient,
                child: const Text('Save & Start Screening'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
