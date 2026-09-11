class SensorReading {
  final String id;
  final String screeningId;
  final DateTime timestamp;
  final int? spo2;
  final int? heartRate;
  final double? pressure;
  final double? coughActivity;

  const SensorReading({
    required this.id,
    required this.screeningId,
    required this.timestamp,
    this.spo2,
    this.heartRate,
    this.pressure,
    this.coughActivity,
  });

  factory SensorReading.empty({required String screeningId}) {
    return SensorReading(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      screeningId: screeningId,
      timestamp: DateTime.now(),
    );
  }

  SensorReading copyWith({
    String? id,
    String? screeningId,
    DateTime? timestamp,
    int? spo2,
    int? heartRate,
    double? pressure,
    double? coughActivity,
  }) {
    return SensorReading(
      id: id ?? this.id,
      screeningId: screeningId ?? this.screeningId,
      timestamp: timestamp ?? this.timestamp,
      spo2: spo2 ?? this.spo2,
      heartRate: heartRate ?? this.heartRate,
      pressure: pressure ?? this.pressure,
      coughActivity: coughActivity ?? this.coughActivity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'screening_id': screeningId,
      'timestamp': timestamp.toIso8601String(),
      'spo2': spo2,
      'heart_rate': heartRate,
      'pressure': pressure,
      'cough_activity': coughActivity,
    };
  }

  factory SensorReading.fromMap(Map<String, dynamic> map) {
    return SensorReading(
      id: map['id'] as String,
      screeningId: (map['screening_id'] as String?) ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      spo2: (map['spo2'] as num?)?.toInt(),
      heartRate: (map['heart_rate'] as num?)?.toInt(),
      pressure: (map['pressure'] as num?)?.toDouble(),
      coughActivity: (map['cough_activity'] as num?)?.toDouble(),
    );
  }
}
