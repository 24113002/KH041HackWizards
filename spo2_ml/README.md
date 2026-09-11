# SwasthAI — SpO2 & PPG Machine Learning Pipeline (XGBoost)

Offline-First Photoplethysmography (PPG) Signal Processing, Classical Pulse Oximetry, and XGBoost Pathology Screening Engine for Rural Healthcare.

---

## 1. Overview
The SpO₂ & PPG ML module processes optical PPG signals from the MAX30102 sensor to provide:
1. **Classical Pulse Oximetry**: Hardware-aligned AC/DC separation, optical modulation $R$-ratio extraction, empirical $SpO_2$ estimation, and heart rate (BPM) detection.
2. **XGBoost PPG Pathology Screening Model**: An engineered physiological feature-based gradient boosting classifier detecting subtle PPG waveform alterations associated with respiratory disease (COPD).

```
MAX30102 Sensor (RED & IR)
          ↓
Signal Quality Assessment (Saturation & Artifact Detection)
          ↓
Butterworth Bandpass (0.5 - 5.0 Hz) + Detrending
          ↓
AC/DC Optical Modulation Separation (R-Ratio)
          ↓
Engineered PPG Feature Extraction (Morphology, Spectral, Relational)
          ↓
XGBoost Respiratory Classifier + Classical SpO2 / HR
          ↓
Multimodal Screening Risk Output
```

---

## 2. Directory Structure
```
spo2_ml/
├── configs/
│   ├── preprocessing.json
│   ├── feature_config.json
│   └── model_config.json
├── data/
│   └── splits/
├── models/
│   ├── spo2_xgb_best.json
│   ├── features.json
│   ├── labels.json
│   └── preprocessing.json
├── outputs/
│   ├── figures/
│   │   ├── diagnostic_ppg_pipeline.png
│   │   ├── feature_importance.png
│   │   ├── confusion_matrix.png
│   │   └── roc_pr_curves.png
│   ├── reports/
│   │   ├── dataset_audit_report.md
│   │   ├── evaluation_metrics.json
│   │   ├── feature_statistics.csv
│   │   └── feature_importance.csv
│   └── experiments/
├── src/
│   ├── data/
│   ├── preprocessing/
│   ├── features/
│   ├── models/
│   ├── tuning/
│   ├── evaluation/
│   ├── inference/
│   └── run_pipeline.py
├── tests/
├── requirements.txt
└── README.md
```

---

## 3. Installation & Execution

### 3.1 Install Dependencies
```bash
pip install -r spo2_ml/requirements.txt
```

### 3.2 Run Full Pipeline
```bash
python -m spo2_ml.src.run_pipeline
```

### 3.3 Individual CLI Commands

**Dataset Audit**:
```bash
python -m spo2_ml.src.data.audit
```

**Run Inference on Raw RED & IR Signals**:
```bash
python -m spo2_ml.src.inference.predict --test_sample
```

**Inference from CSV File**:
```bash
python -m spo2_ml.src.inference.predict --csv "path/to/ppg_recording.csv"
```

---

## 4. Hardware Integration & Saturation Rejection
- **MAX30102 ADC Saturation Floor/Ceiling**: Values exceeding $262,140$ or dropping below $1,000$ (e.g., finger removed) are automatically flagged and rejected with `status = "INVALID_SIGNAL"`.
- **Zero Hallucination**: When signal quality is poor, the system outputs `spo2_classical_estimate = null` rather than fabricating inaccurate vital metrics.
