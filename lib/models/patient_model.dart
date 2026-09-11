import 'dart:math';

enum Gender { male, female, other }

class Patient {
  final String id;
  final String name;
  final int age;
  final Gender gender;
  final double heightCm;
  final double weightKg;
  final String phone;
  final String medicalHistory;
  final DateTime createdAt;

  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    this.phone = '',
    this.medicalHistory = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Calculates Body Mass Index (BMI)
  double get bmi {
    if (heightCm <= 0) return 0.0;
    final heightM = heightCm / 100.0;
    return weightKg / (heightM * heightM);
  }

  /// Calculates predicted Forced Vital Capacity (FVC in Liters)
  /// Using standard European Respiratory Society / Knudson reference equations
  double get predictedFvc {
    final h = heightCm / 100.0;
    if (gender == Gender.male) {
      // Male reference: (5.76 * H) - (0.026 * Age) - 4.34
      return max(1.0, (5.76 * h) - (0.026 * age) - 4.34);
    } else {
      // Female reference: (4.43 * H) - (0.026 * Age) - 2.89
      return max(1.0, (4.43 * h) - (0.026 * age) - 2.89);
    }
  }

  /// Calculates predicted Forced Expiratory Volume in 1 second (FEV1 in Liters)
  double get predictedFev1 {
    final h = heightCm / 100.0;
    if (gender == Gender.male) {
      // Male reference: (4.30 * H) - (0.029 * Age) - 2.49
      return max(0.8, (4.30 * h) - (0.029 * age) - 2.49);
    } else {
      // Female reference: (3.95 * H) - (0.025 * Age) - 2.60
      return max(0.8, (3.95 * h) - (0.025 * age) - 2.60);
    }
  }

  /// Calculates predicted Peak Expiratory Flow (PEF in L/min)
  double get predictedPef {
    final h = heightCm / 100.0;
    if (gender == Gender.male) {
      // Male reference: ((6.14 * H) - (0.043 * Age) + 0.15) * 60
      return max(150.0, ((6.14 * h) - (0.043 * age) + 0.15) * 60);
    } else {
      // Female reference: ((5.50 * H) - (0.030 * Age) - 1.11) * 60
      return max(120.0, ((5.50 * h) - (0.030 * age) - 1.11) * 60);
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'gender': gender.name,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'phone': phone,
      'medical_history': medicalHistory,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      id: map['id'] as String,
      name: map['name'] as String,
      age: map['age'] as int,
      gender: Gender.values.firstWhere(
        (g) => g.name == (map['gender'] as String?),
        orElse: () => Gender.male,
      ),
      heightCm: (map['height_cm'] as num).toDouble(),
      weightKg: (map['weight_kg'] as num).toDouble(),
      phone: (map['phone'] as String?) ?? '',
      medicalHistory: (map['medical_history'] as String?) ?? '',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
