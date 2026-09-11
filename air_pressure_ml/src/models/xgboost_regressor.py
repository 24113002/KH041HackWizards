"""
SwasthAI Air-Pressure ML - XGBoost Model Wrapper
Provides unified interface for training, evaluation, feature importance, and JSON serialization.
"""

import os
import json
import numpy as np
import xgboost as xgb
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

class AirPressureXGBModel:
    def __init__(self, task: str = "regression", params: dict = None):
        self.task = task
        self.params = params or {
            'n_estimators': 80,
            'max_depth': 3,
            'learning_rate': 0.05,
            'subsample': 0.8,
            'colsample_bytree': 0.8,
            'min_child_weight': 3,
            'gamma': 0.1,
            'reg_alpha': 0.01,
            'reg_lambda': 0.01,
            'random_state': 42
        }
        
        if self.task == "regression":
            self.model = xgb.XGBRegressor(**self.params)
        else:
            self.model = xgb.XGBClassifier(**self.params)
            
        self.feature_names = []

    def fit(self, X: np.ndarray, y: np.ndarray, feature_names: list = None, eval_set: list = None):
        self.feature_names = feature_names or [f"f{i}" for i in range(X.shape[1])]
        if eval_set:
            self.model.fit(X, y, eval_set=eval_set, verbose=False)
        else:
            self.model.fit(X, y)
        return self

    def predict(self, X: np.ndarray) -> np.ndarray:
        return self.model.predict(X)

    def predict_proba(self, X: np.ndarray) -> np.ndarray:
        if hasattr(self.model, "predict_proba"):
            return self.model.predict_proba(X)
        return None

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
        if self.task == "regression":
            self.model = xgb.XGBRegressor()
        else:
            self.model = xgb.XGBClassifier()
        self.model.load_model(file_path)
