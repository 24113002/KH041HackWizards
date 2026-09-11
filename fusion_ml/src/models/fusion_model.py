"""
SwasthAI Fusion ML - Multimodal XGBoost Classifier Wrapper
Handles multi-class late fusion (Lower, Moderate, Higher Risk) with native missing value handling.
"""

import os
import json
import numpy as np
import xgboost as xgb

class SwasthAIFusionModel:
    def __init__(self, params: dict = None):
        self.params = params or {
            'objective': 'multi:softprob',
            'num_class': 3,
            'n_estimators': 80,
            'max_depth': 3,
            'learning_rate': 0.05,
            'subsample': 0.8,
            'colsample_bytree': 0.8,
            'min_child_weight': 2,
            'gamma': 0.1,
            'reg_alpha': 0.01,
            'reg_lambda': 0.01,
            'random_state': 42
        }
        self.model = xgb.XGBClassifier(**self.params)
        self.feature_names = []
        self.class_labels = {
            '0': 'LOWER_RISK',
            '1': 'MODERATE_RISK',
            '2': 'HIGHER_RISK'
        }

    def fit(self, X: np.ndarray, y: np.ndarray, feature_names: list = None):
        self.feature_names = feature_names or [f"f{i}" for i in range(X.shape[1])]
        self.model.fit(X, y)
        return self

    def predict(self, X: np.ndarray) -> np.ndarray:
        preds = self.model.predict(X)
        if preds.ndim > 1:
            preds = np.argmax(preds, axis=1)
        return preds

    def predict_proba(self, X: np.ndarray) -> np.ndarray:
        return self.model.predict_proba(X)

    def get_feature_importance(self) -> dict:
        if hasattr(self.model, "feature_importances_"):
            importances = self.model.feature_importances_
            return {
                name: float(imp)
                for name, imp in sorted(zip(self.feature_names, importances), key=lambda x: x[1], reverse=True)
            }
        return {}

    def save_model(self, file_path: str):
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
        self.model.save_model(file_path)

    def load_model(self, file_path: str):
        self.model = xgb.XGBClassifier()
        self.model.load_model(file_path)
