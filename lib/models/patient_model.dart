import 'dart:math';

enum Gender { male, female, other }

class Patient {
  final String id;
  final String fullName;
  final int age;
  final Gender gender;
  final String village;
  final String occupation;
  final String smokingStatus; // Non-smoker, Former smoker, Current smoker
  final double heightCm;
  final double weightKg;
  final String phone;
  final String medicalHistory;
  final DateTime createdAt;
  final DateTime updatedAt;

  Patient({
    required this.id,
    String? fullName,
    String? name,
    required this.age,
    required this.gender,
    this.village = '',
    this.occupation = '',
    this.smokingStatus = 'Non-smoker',
    double? heightCm,
    double? weightKg,
    this.phone = '',
    this.medicalHistory = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : fullName = (fullName != null && fullName.isNotEmpty) ? fullName : (name ?? ''),
        heightCm = heightCm ?? 165.0,
        weightKg = weightKg ?? 65.0,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Backward-compatibility alias
  String get name => fullName;

  /// Validation helper for forms and data integrity
  String? validate() {
    if (fullName.trim().isEmpty) return 'Full name is required.';
    if (age < 1 || age > 120) return 'Please enter a valid age between 1 and 120.';
    return null;
  }

  /// Calculates Body Mass Index (BMI)
  double get bmi {
    if (heightCm <= 0) return 0.0;
    final heightM = heightCm / 100.0;
    return weightKg / (heightM * heightM);
  }

  /// Calculates predicted Forced Vital Capacity (FVC in Liters)
  double get predictedFvc {
    final h = heightCm / 100.0;
    if (gender == Gender.male) {
      return max(1.0, (5.76 * h) - (0.026 * age) - 4.34);
    } else {
      return max(1.0, (4.43 * h) - (0.026 * age) - 2.89);
    }
  }

  /// Calculates predicted Forced Expiratory Volume in 1 second (FEV1 in Liters)
  double get predictedFev1 {
    final h = heightCm / 100.0;
    if (gender == Gender.male) {
      return max(0.8, (4.30 * h) - (0.029 * age) - 2.49);
    } else {
      return max(0.8, (3.95 * h) - (0.025 * age) - 2.60);
    }
  }

  /// Calculates predicted Peak Expiratory Flow (PEF in L/min)
  double get predictedPef {
    final h = heightCm / 100.0;
    if (gender == Gender.male) {
      return max(150.0, ((6.14 * h) - (0.043 * age) + 0.15) * 60);
    } else {
      return max(120.0, ((5.50 * h) - (0.030 * age) - 1.11) * 60);
    }
  }

  Patient copyWith({
    String? id,
    String? fullName,
    String? name,
    int? age,
    Gender? gender,
    String? village,
    String? occupation,
    String? smokingStatus,
    double? heightCm,
    double? weightKg,
    String? phone,
    String? medicalHistory,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Patient(
      id: id ?? this.id,
      fullName: fullName ?? name ?? this.fullName,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      village: village ?? this.village,
      occupation: occupation ?? this.occupation,
      smokingStatus: smokingStatus ?? this.smokingStatus,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      phone: phone ?? this.phone,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'name': fullName, // compatibility
      'age': age,
      'gender': gender.name,
      'village': village,
      'occupation': occupation,
      'smoking_status': smokingStatus,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'phone': phone,
      'medical_history': medicalHistory,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    final nameStr = (map['full_name'] as String?) ?? (map['name'] as String?) ?? '';
    return Patient(
      id: map['id'] as String,
      fullName: nameStr,
      age: (map['age'] as num).toInt(),
      gender: Gender.values.firstWhere(
        (g) => g.name.toLowerCase() == ((map['gender'] as String?) ?? '').toLowerCase(),
        orElse: () => Gender.male,
      ),
      village: (map['village'] as String?) ?? '',
      occupation: (map['occupation'] as String?) ?? '',
      smokingStatus: (map['smoking_status'] as String?) ?? 'Non-smoker',
      heightCm: (map['height_cm'] as num?)?.toDouble() ?? 165.0,
      weightKg: (map['weight_kg'] as num?)?.toDouble() ?? 65.0,
      phone: (map['phone'] as String?) ?? '',
      medicalHistory: (map['medical_history'] as String?) ?? '',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
