"""
SwasthAI SpO2 & PPG ML - XGBoost Classifier & Regressor Module
"""

import os
import json
import xgboost as xgb
import numpy as np
import pandas as pd
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    roc_auc_score, average_precision_score, confusion_matrix
)

class SwasthAIXGBoostModel:
    def __init__(
        self,
        n_estimators: int = 150,
        max_depth: int = 4,
        learning_rate: float = 0.05,
        subsample: float = 0.8,
        colsample_bytree: float = 0.8,
        min_child_weight: int = 3,
        gamma: float = 0.1,
        reg_alpha: float = 0.05,
        reg_lambda: float = 1.0,
        random_state: int = 42
    ):
        self.params = {
            'n_estimators': n_estimators,
            'max_depth': max_depth,
            'learning_rate': learning_rate,
            'subsample': subsample,
            'colsample_bytree': colsample_bytree,
            'min_child_weight': min_child_weight,
            'gamma': gamma,
            'reg_alpha': reg_alpha,
            'reg_lambda': reg_lambda,
            'random_state': random_state,
            'eval_metric': 'logloss',
            'n_jobs': -1
        }
        self.model = xgb.XGBClassifier(**self.params)
        self.feature_names = []

    def fit(self, X_train, y_train, X_val=None, y_val=None, feature_names=None):
        if feature_names is not None:
            self.feature_names = list(feature_names)
            
        eval_set = [(X_train, y_train)]
        if X_val is not None and y_val is not None:
            eval_set.append((X_val, y_val))
            
        self.model.fit(
            X_train, y_train,
            eval_set=eval_set,
            verbose=False
        )

    def predict_proba(self, X):
        return self.model.predict_proba(X)

    def predict(self, X):
        return self.model.predict(X)

    def evaluate(self, X_test, y_test):
        preds = self.model.predict(X_test)
        probs = self.model.predict_proba(X_test)[:, 1]
        
        acc = accuracy_score(y_test, preds)
        prec = precision_score(y_test, preds, zero_division=0)
        rec = recall_score(y_test, preds, zero_division=0)
        f1 = f1_score(y_test, preds, zero_division=0)
        roc_auc = roc_auc_score(y_test, probs) if len(np.unique(y_test)) > 1 else 0.5
        pr_auc = average_precision_score(y_test, probs) if len(np.unique(y_test)) > 1 else 0.5
        
        cm = confusion_matrix(y_test, preds)
        
        return {
            'accuracy': float(acc),
            'precision': float(prec),
            'recall': float(rec),
            'f1': float(f1),
            'roc_auc': float(roc_auc),
            'pr_auc': float(pr_auc),
            'confusion_matrix': cm.tolist()
        }, preds, probs

    def get_feature_importances(self) -> pd.DataFrame:
        importances = self.model.feature_importances_
        names = self.feature_names if self.feature_names else [f"f_{i}" for i in range(len(importances))]
        df_imp = pd.DataFrame({
            'feature': names,
            'importance': importances
        }).sort_values(by='importance', ascending=False).reset_index(drop=True)
        return df_imp

    def save_model(self, output_path: str = "spo2_ml/models/spo2_xgb_best.json"):
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        self.model.save_model(output_path)
        print(f"Saved XGBoost model to: {output_path}")

    def load_model(self, input_path: str = "spo2_ml/models/spo2_xgb_best.json"):
        self.model.load_model(input_path)
        print(f"Loaded XGBoost model from: {input_path}")
