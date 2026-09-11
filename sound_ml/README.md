# SwasthAI — PyTorch Respiratory Sound ML Pipeline

Offline-First Respiratory Sound Classification Engine for Rural Healthcare Screening.

---

## 1. Overview
This module trains and exports a lightweight PyTorch deep learning model to classify respiratory sounds from electronic stethoscope recordings.

### Key Architecture:
- **Audio Preprocessing**: Standardized to 4,000 Hz Mono, 5.0s segmentation, and Log-Mel Spectrogram extraction ($n\_fft=512$, $n\_mels=64$, $hop\_length=128$, range 50–2,000 Hz).
- **Leakage-Free Patient Splitting**: Audio files from the same patient (BP, DP, EP filter modes) are kept strictly within the same data split (70% Train, 15% Val, 15% Test).
- **Self-Supervised Pretraining**: Leverages 920 unlabelled respiratory audio files (ICBHI database, 5.49 hours) via a Masked Spectrogram Autoencoder (MAE).
- **Supervised PyTorch CNN**: Lightweight 4-block Conv2D + BatchNorm + ReLU + Dropout + Global Pooling network (< 150k parameters).
- **Hyperparameter Optimization**: Automated Optuna study tuning convolutional filters, dropout, learning rate, and weight decay.
- **Export Formats**: PyTorch State Dict (`.pt`) and ONNX (`.onnx`) ready for offline deployment.

---

## 2. Directory Structure
```
sound_ml/
├── configs/
│   └── default_config.json
├── data/
│   └── splits/
├── models/
│   ├── sound_model_best.pt
│   ├── sound_model.onnx
│   ├── labels.json
│   └── preprocessing.json
├── outputs/
│   ├── figures/
│   │   ├── loss_progression_curve.png
│   │   ├── confusion_matrix.png
│   │   ├── roc_pr_curves.png
│   │   └── gradcam_saliency.png
│   ├── reports/
│   │   ├── evaluation_metrics.json
│   │   └── error_analysis.json
│   └── experiments/
├── src/
│   ├── data/
│   ├── preprocessing/
│   ├── models/
│   ├── training/
│   ├── tuning/
│   ├── evaluation/
│   ├── inference/
│   └── run_pipeline.py
├── tests/
├── requirements.txt
└── README.md
```

---

## 3. Installation & Usage

### 3.1 Installation
```bash
pip install -r sound_ml/requirements.txt
```

### 3.2 Run Complete Pipeline
```bash
python -m sound_ml.src.run_pipeline
```

### 3.3 Individual CLI Commands

**Dataset Audit**:
```bash
python -m sound_ml.src.data.audit --labelled_path "dataset-lung sounds/labelled data" --unlabelled_path "dataset-lung sounds/unlabelled data"
```

**Optuna Hyperparameter Tuning**:
```bash
python -m sound_ml.src.tuning.optimize
```

**Model Training**:
```bash
python -m sound_ml.src.training.train_final
```

**Evaluation & Graph Plotting**:
```bash
python -m sound_ml.src.evaluation.evaluate
```

**Inference on New Audio File**:
```bash
python -m sound_ml.src.inference.predict --audio "path/to/recording.wav"
```

---

## 4. Medical Safety & Disclaimer
> [!IMPORTANT]
> This model is a **screening-support tool** developed for rural health workers. It identifies acoustic adventitious features (wheezes, crackles) and does **NOT** provide a standalone clinical diagnosis of COPD or any other medical condition.
