"""
SwasthAI Sound ML - Classical Machine Learning Baseline (MFCC + Random Forest / SVM)
"""

import numpy as np
import scipy.signal
import scipy.fft
from sklearn.ensemble import RandomForestClassifier
from sklearn.svm import SVC
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, roc_auc_score
from ..preprocessing.audio_transforms import load_audio_wav

def extract_classical_features(audio: np.ndarray, sr: int = 4000) -> np.ndarray:
    """
    Extracts classical audio features: Spectral Centroid, Spread, Energy, Zero-Crossing Rate, and STFT summary statistics.
    """
    feats = []
    
    # 1. Zero Crossing Rate
    zcr = np.mean(np.abs(np.diff(np.sign(audio)))) / 2.0
    feats.append(zcr)
    
    # 2. Energy / RMS
    rms = np.sqrt(np.mean(audio ** 2))
    feats.append(rms)
    
    # 3. Frequency Spectrum
    freqs, times, stft = scipy.signal.stft(audio, fs=sr, nperseg=256, noverlap=128)
    magnitude = np.abs(stft) # [F, T]
    
    # Spectral Centroid
    freq_weights = freqs[:, np.newaxis]
    mag_sum = np.sum(magnitude, axis=0) + 1e-8
    centroid = np.sum(magnitude * freq_weights, axis=0) / mag_sum
    feats.extend([np.mean(centroid), np.std(centroid), np.max(centroid), np.min(centroid)])
    
    # Spectral Flatness
    geo_mean = np.exp(np.mean(np.log(magnitude + 1e-8), axis=0))
    arith_mean = np.mean(magnitude, axis=0) + 1e-8
    flatness = geo_mean / arith_mean
    feats.extend([np.mean(flatness), np.std(flatness)])
    
    # Sub-band Energies (Low: 50-250 Hz, Mid: 250-800 Hz, High: 800-2000 Hz)
    low_band = magnitude[(freqs >= 50) & (freqs < 250), :]
    mid_band = magnitude[(freqs >= 250) & (freqs < 800), :]
    high_band = magnitude[(freqs >= 800) & (freqs <= 2000), :]
    
    feats.extend([
        np.mean(np.sum(low_band, axis=0)),
        np.mean(np.sum(mid_band, axis=0)),
        np.mean(np.sum(high_band, axis=0))
    ])
    
    # FFT Band Power Statistics
    for band in np.array_split(magnitude, 8, axis=0):
        feats.append(np.mean(band))
        feats.append(np.std(band))
        
    return np.array(feats, dtype=np.float32)

class ClassicalMLBaseline:
    def __init__(self, model_type: str = 'rf'):
        self.model_type = model_type
        if model_type == 'rf':
            self.model = RandomForestClassifier(n_estimators=100, random_state=42, class_weight='balanced')
        elif model_type == 'svm':
            self.model = SVC(kernel='rbf', probability=True, random_state=42, class_weight='balanced')
        else:
            self.model = LogisticRegression(max_iter=1000, random_state=42, class_weight='balanced')
            
    def extract_dataset_features(self, records: list, sr: int = 4000, target_duration_sec: float = 5.0):
        X = []
        y = []
        for rec in records:
            audio = load_audio_wav(rec['file_path'], sr, target_duration_sec)
            feat = extract_classical_features(audio, sr)
            X.append(feat)
            y.append(rec['label'])
        return np.array(X), np.array(y)
        
    def train(self, X_train, y_train):
        self.model.fit(X_train, y_train)
        
    def evaluate(self, X_test, y_test):
        preds = self.model.predict(X_test)
        probs = self.model.predict_proba(X_test)[:, 1] if hasattr(self.model, 'predict_proba') else None
        
        metrics = {
            'accuracy': float(accuracy_score(y_test, preds)),
            'precision': float(precision_score(y_test, preds, zero_division=0)),
            'recall': float(recall_score(y_test, preds, zero_division=0)),
            'f1': float(f1_score(y_test, preds, zero_division=0)),
            'roc_auc': float(roc_auc_score(y_test, probs)) if probs is not None and len(np.unique(y_test)) > 1 else None
        }
        return metrics, preds, probs
