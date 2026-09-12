class VitalsReading {
  final int heartRate; // bpm
  final int spo2; // percentage (0-100)
  final double ppgValue; // raw or normalized PPG signal for graphing
  final DateTime timestamp;

  const VitalsReading({
    required this.heartRate,
    required this.spo2,
    required this.ppgValue,
    required this.timestamp,
  });

  factory VitalsReading.initial() {
    return VitalsReading(
      heartRate: 75,
      spo2: 98,
      ppgValue: 0.0,
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'heart_rate': heartRate,
      'spo2': spo2,
      'ppg_value': ppgValue,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory VitalsReading.fromMap(Map<String, dynamic> map) {
    return VitalsReading(
      heartRate: (map['heart_rate'] as num?)?.toInt() ?? 0,
      spo2: (map['spo2'] as num?)?.toInt() ?? 0,
      ppgValue: (map['ppg_value'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class SpirometryPoint {
  final double timeSec;
  final double flowLps; // Flow in Liters per second
  final double volumeLiters; // Integrated exhalation volume

  const SpirometryPoint({
    required this.timeSec,
    required this.flowLps,
    required this.volumeLiters,
  });

  Map<String, dynamic> toMap() {
    return {
      'time_sec': timeSec,
      'flow_lps': flowLps,
      'volume_liters': volumeLiters,
    };
  }

  factory SpirometryPoint.fromMap(Map<String, dynamic> map) {
    return SpirometryPoint(
      timeSec: (map['time_sec'] as num).toDouble(),
      flowLps: (map['flow_lps'] as num).toDouble(),
      volumeLiters: (map['volume_liters'] as num).toDouble(),
    );
  }
}

class SpirometrySummary {
  final double fev1; // Forced Expiratory Volume in 1 second (L)
  final double fvc; // Forced Vital Capacity total volume (L)
  final double fev1FvcRatio; // Ratio (usually expressed as decimal e.g. 0.78 or percentage 78%)
  final double pefLpm; // Peak Expiratory Flow in Liters per minute
  final double forcedExpiratoryTimeSec; // Duration of forced blow (FET)

  const SpirometrySummary({
    required this.fev1,
    required this.fvc,
    required this.fev1FvcRatio,
    required this.pefLpm,
    required this.forcedExpiratoryTimeSec,
  });

  factory SpirometrySummary.empty() {
    return const SpirometrySummary(
      fev1: 0.0,
      fvc: 0.0,
      fev1FvcRatio: 0.0,
      pefLpm: 0.0,
      forcedExpiratoryTimeSec: 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fev1': fev1,
      'fvc': fvc,
      'fev1_fvc_ratio': fev1FvcRatio,
      'pef_lpm': pefLpm,
      'fet_sec': forcedExpiratoryTimeSec,
    };
  }

  factory SpirometrySummary.fromMap(Map<String, dynamic> map) {
    return SpirometrySummary(
      fev1: (map['fev1'] as num?)?.toDouble() ?? 0.0,
      fvc: (map['fvc'] as num?)?.toDouble() ?? 0.0,
      fev1FvcRatio: (map['fev1_fvc_ratio'] as num?)?.toDouble() ?? 0.0,
      pefLpm: (map['pef_lpm'] as num?)?.toDouble() ?? 0.0,
      forcedExpiratoryTimeSec: (map['fet_sec'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AcousticReading {
  final double rmsAmplitude; // 0.0 to 1.0 sound loudness
  final bool coughDetected;
  final double dominantFreqHz;
  final DateTime timestamp;

  const AcousticReading({
    required this.rmsAmplitude,
    required this.coughDetected,
    required this.dominantFreqHz,
    required this.timestamp,
  });

  factory AcousticReading.initial() {
    return AcousticReading(
      rmsAmplitude: 0.0,
      coughDetected: false,
      dominantFreqHz: 0.0,
      timestamp: DateTime.now(),
    );
  }
}

class AcousticSummary {
  final int coughCount;
  final double peakRms;
  final double averageRms;
  final bool wheezeDetected;

  const AcousticSummary({
    required this.coughCount,
    required this.peakRms,
    required this.averageRms,
    required this.wheezeDetected,
  });

  factory AcousticSummary.empty() {
    return const AcousticSummary(
      coughCount: 0,
      peakRms: 0.0,
      averageRms: 0.0,
      wheezeDetected: false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cough_count': coughCount,
      'peak_rms': peakRms,
      'average_rms': averageRms,
      'wheeze_detected': wheezeDetected ? 1 : 0,
    };
  }

  factory AcousticSummary.fromMap(Map<String, dynamic> map) {
    return AcousticSummary(
      coughCount: (map['cough_count'] as num?)?.toInt() ?? 0,
      peakRms: (map['peak_rms'] as num?)?.toDouble() ?? 0.0,
      averageRms: (map['average_rms'] as num?)?.toDouble() ?? 0.0,
      wheezeDetected: (map['wheeze_detected'] as num?)?.toInt() == 1,
    );
  }
}
