import 'dart:async';
import 'dart:math';
import '../models/sensor_data_model.dart';
import '../models/sensor_reading_model.dart';

abstract class SensorService {
  SensorReading getMockSensorReading({required String screeningId});
  VitalsReading getLatestVitals();
  Stream<VitalsReading> get vitalsStream;
  Stream<SpirometryPoint> get spirometryStream;
  Stream<AcousticReading> get acousticStream;
  void startVitalsStream();
  void stopVitalsStream();
  void simulateBreathingManeuver();
  void simulateCoughEvent();
  void dispose();
}

class MockSensorService implements SensorService {
  final _vitalsController = StreamController<VitalsReading>.broadcast();
  final _spirometryController = StreamController<SpirometryPoint>.broadcast();
  final _acousticController = StreamController<AcousticReading>.broadcast();

  Timer? _vitalsTimer;
  Timer? _spirometryTimer;
  Timer? _acousticTimer;
  double _phase = 0.0;
  bool _isStreamingVitals = false;

  MockSensorService() {
    startVitalsStream();
  }

  @override
  SensorReading getMockSensorReading({required String screeningId}) {
    return SensorReading(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      screeningId: screeningId,
      timestamp: DateTime.now(),
      spo2: 97,
      heartRate: 82,
      pressure: 1.84,
      coughActivity: 0.72,
    );
  }

  @override
  VitalsReading getLatestVitals() {
    return VitalsReading(
      heartRate: 82,
      spo2: 97,
      ppgValue: 0.52,
      timestamp: DateTime.now(),
    );
  }

  @override
  Stream<VitalsReading> get vitalsStream => _vitalsController.stream;

  @override
  Stream<SpirometryPoint> get spirometryStream => _spirometryController.stream;

  @override
  Stream<AcousticReading> get acousticStream => _acousticController.stream;

  @override
  void startVitalsStream() {
    if (_isStreamingVitals) return;
    _isStreamingVitals = true;

    _vitalsTimer?.cancel();
    _vitalsTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _phase += 0.25;
      // Synthesize realistic pulsatile PPG waveform: primary systolic peak + dicrotic notch
      final ppg = (sin(_phase) * 0.4 + sin(_phase * 2) * 0.15 + 0.5).clamp(0.05, 0.95);
      // Subtle physiological jitter for realistic display
      final hrJitter = (sin(_phase * 0.1) * 2).round();
      final hr = (82 + hrJitter).clamp(78, 86);

      if (!_vitalsController.isClosed) {
        _vitalsController.add(
          VitalsReading(
            heartRate: hr,
            spo2: 97,
            ppgValue: ppg,
            timestamp: DateTime.now(),
          ),
        );
      }
    });
  }

  @override
  void stopVitalsStream() {
    _vitalsTimer?.cancel();
    _vitalsTimer = null;
    _isStreamingVitals = false;
  }

  @override
  void simulateBreathingManeuver() {
    _spirometryTimer?.cancel();
    double time = 0.0;
    double cumulativeVolume = 0.0;
    const intervalMs = 50;
    const totalDurationSec = 3.5;

    _spirometryTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (timer) {
      time += (intervalMs / 1000.0);

      // Expiratory flow curve modeling: quick rise to Peak Expiratory Flow, exponential decay
      double flowLps = 0.0;
      if (time <= 0.2) {
        // Rapid acceleration up to peak ~7.5 L/s (450 L/min)
        flowLps = (time / 0.2) * 7.5;
      } else {
        // Exponential decay
        flowLps = 7.5 * exp(-1.1 * (time - 0.2));
      }
      flowLps = max(0.0, flowLps);

      // Integrate volume (Liters)
      cumulativeVolume += flowLps * (intervalMs / 1000.0);
      cumulativeVolume = min(3.85, cumulativeVolume);

      // Pressure in kPa correlated to flow (1.84 kPa peak)
      final pressureKpa = (flowLps / 7.5) * 1.84;

      if (!_spirometryController.isClosed) {
        _spirometryController.add(
          SpirometryPoint(
            timeSeconds: time,
            flowLps: flowLps,
            volumeL: cumulativeVolume,
            pressureKpa: pressureKpa,
          ),
        );
      }

      if (time >= totalDurationSec) {
        timer.cancel();
      }
    });
  }

  @override
  void simulateCoughEvent() {
    _acousticTimer?.cancel();
    int step = 0;
    const intervalMs = 80;

    _acousticTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (timer) {
      step++;
      // Burst amplitude for cough sound
      double rms = 0.05;
      if (step >= 3 && step <= 7) {
        rms = (0.72 + sin(step.toDouble()) * 0.15).clamp(0.0, 1.0);
      }

      if (!_acousticController.isClosed) {
        _acousticController.add(
          AcousticReading(
            rmsAmplitude: rms,
            isCoughTriggered: step == 4 || step == 5,
            timestamp: DateTime.now(),
          ),
        );
      }

      if (step >= 15) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    stopVitalsStream();
    _spirometryTimer?.cancel();
    _acousticTimer?.cancel();
    _vitalsController.close();
    _spirometryController.close();
    _acousticController.close();
  }
}
