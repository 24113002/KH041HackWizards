import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../controllers/patient_provider.dart';
import '../models/patient_model.dart';
import '../theme/app_theme.dart';

class AddEditPatientScreen extends StatefulWidget {
  final Patient? patient;

  const AddEditPatientScreen({super.key, this.patient});

  @override
  State<AddEditPatientScreen> createState() => _AddEditPatientScreenState();
}

class _AddEditPatientScreenState extends State<AddEditPatientScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _villageController;
  late TextEditingController _occupationController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _phoneController;
  late TextEditingController _historyController;

  late Gender _selectedGender;
  late String _selectedSmokingStatus;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.patient;
    _nameController = TextEditingController(text: p?.fullName ?? '');
    _ageController = TextEditingController(text: p != null ? p.age.toString() : '45');
    _villageController = TextEditingController(text: p?.village ?? '');
    _occupationController = TextEditingController(text: p?.occupation ?? '');
    _heightController = TextEditingController(text: p != null ? p.heightCm.toStringAsFixed(0) : '165');
    _weightController = TextEditingController(text: p != null ? p.weightKg.toStringAsFixed(0) : '65');
    _phoneController = TextEditingController(text: p?.phone ?? '');
    _historyController = TextEditingController(text: p?.medicalHistory ?? '');

    _selectedGender = p?.gender ?? Gender.male;
    _selectedSmokingStatus = p?.smokingStatus ?? 'Non-smoker';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _villageController.dispose();
    _occupationController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _phoneController.dispose();
    _historyController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final provider = context.read<PatientProvider>();

    final isEdit = widget.patient != null;
    final patient = Patient(
      id: widget.patient?.id ?? const Uuid().v4(),
      fullName: _nameController.text.trim(),
      age: int.parse(_ageController.text.trim()),
      gender: _selectedGender,
      village: _villageController.text.trim(),
      occupation: _occupationController.text.trim(),
      smokingStatus: _selectedSmokingStatus,
      heightCm: double.tryParse(_heightController.text.trim()) ?? 165.0,
      weightKg: double.tryParse(_weightController.text.trim()) ?? 65.0,
      phone: _phoneController.text.trim(),
      medicalHistory: _historyController.text.trim(),
      createdAt: widget.patient?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    bool success;
    if (isEdit) {
      success = await provider.updatePatient(patient);
    } else {
      success = await provider.createPatient(patient);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Patient updated successfully.' : 'Patient added successfully.'),
            backgroundColor: AppTheme.riskLow,
          ),
        );
        Navigator.pop(context, patient);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Unable to save patient. Please try again.'),
            backgroundColor: AppTheme.riskCritical,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.patient != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Patient Profile' : 'Register New Patient',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Offline Indicator Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryTeal.withAlpha(60)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sd_card_alert_outlined, size: 14, color: AppTheme.primaryTeal),
                    SizedBox(width: 6),
                    Text(
                      'OFFLINE MODE: Stored on this device',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Full Name
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  hintText: 'e.g. Rahul Patil',
                  prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryTeal),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Full Name is required';
                  }
                  if (val.trim().length < 2) {
                    return 'Please enter a valid full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Age & Gender Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Age (Years) *',
                        hintText: '1 - 120',
                        prefixIcon: Icon(Icons.cake_outlined, color: AppTheme.primaryTeal),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Age is required';
                        final age = int.tryParse(val.trim());
                        if (age == null || age <= 0 || age > 120) {
                          return 'Age must be 1 - 120';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: DropdownButtonFormField<Gender>(
                      initialValue: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Biological Sex *',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
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
              const SizedBox(height: 16),

              // Village & Occupation Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _villageController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Village / Location',
                        hintText: 'e.g. Khed',
                        prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.primaryTeal),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _occupationController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Occupation',
                        hintText: 'e.g. Farmer',
                        prefixIcon: Icon(Icons.work_outline, color: AppTheme.primaryTeal),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Smoking Status Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedSmokingStatus,
                decoration: const InputDecoration(
                  labelText: 'Tobacco Smoking Status *',
                  prefixIcon: Icon(Icons.smoke_free, color: AppTheme.primaryTeal),
                ),
                dropdownColor: AppTheme.surfaceElevated,
                items: const [
                  DropdownMenuItem(value: 'Non-smoker', child: Text('Non-smoker')),
                  DropdownMenuItem(value: 'Former smoker', child: Text('Former smoker')),
                  DropdownMenuItem(value: 'Current smoker', child: Text('Current smoker')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSmokingStatus = val);
                },
              ),
              const SizedBox(height: 16),

              // Optional Height & Weight for Predicted Spirometry Calculations
              ExpansionTile(
                title: const Text('Physical Reference Measurements (Optional)', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                tilePadding: EdgeInsets.zero,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _heightController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Height (cm)',
                            prefixIcon: Icon(Icons.height),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextFormField(
                          controller: _weightController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Weight (kg)',
                            prefixIcon: Icon(Icons.monitor_weight_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _historyController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Known Medical History & Notes',
                      hintText: 'e.g. Asthma, Hypertension, Biomass smoke exposure',
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submitForm,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(isEdit ? Icons.check : Icons.person_add),
                  label: Text(
                    _isSaving
                        ? 'Saving Patient...'
                        : (isEdit ? 'Save Changes' : 'Register Patient & Continue'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
