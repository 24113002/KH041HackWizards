# SwasthAI: Air-Pressure & Respiratory ML Component

Offline-first respiratory pressure estimation and airway obstruction risk screening module using ESP32 + HX710B + MPS20N0040D pressure sensor data and XGBoost.

## Architecture

```
ESP32 + HX710B (Raw ADC) -> Resting Baseline -> Zero-Phase Filter (5Hz LP) -> Blow Segmentation -> Feature Extraction -> XGBoost -> Respiratory Pressure & Risk
```

## Features Extracted (22 Physiological Features)
- **Baseline**: Mean, Std, Drift, Stability
- **Pressure/Delta**: Peak Delta, Mean Delta, Std Delta, RMS Delta, Dynamic Range
- **Dynamics**: Rise Time, Fall Time, Blow Duration, Time-to-Peak, Time above 50%
- **Derivatives**: Max Rise Rate, Max Fall Rate, Mean Rise Rate, Derivative Std
- **Area**: Total AUC, Positive AUC
- **Shape**: Skewness, Kurtosis, Rise/Fall Ratio
- **Spectral**: Dominant Frequency, Spectral Centroid, Spectral Entropy

## Quickstart

```bash
# Run complete end-to-end pipeline
python -m air_pressure_ml.src.run_pipeline

# Run standalone inference on raw sample
python -m air_pressure_ml.src.inference.inference --test_sample

# Run automated unit tests
python -m unittest air_pressure_ml/tests/test_airpressure_pipeline.py
```
