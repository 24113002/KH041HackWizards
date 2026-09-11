"""
SwasthAI Air-Pressure ML - Optuna Hyperparameter Optimization Module
Implements GroupKFold cross-validation grouped by subject_id (zero data leakage).
"""

import optuna
import numpy as np
import xgboost as xgb
from sklearn.model_selection import GroupKFold
from sklearn.metrics import mean_squared_error

optuna.logging.set_verbosity(optuna.logging.WARNING)

class AirPressureOptunaTuner:
    def __init__(self, n_trials: int = 25, n_splits: int = 4, random_state: int = 42):
        self.n_trials = n_trials
        self.n_splits = n_splits
        self.random_state = random_state

    def tune_regression(self, X: np.ndarray, y: np.ndarray, groups: np.ndarray) -> dict:
        gkf = GroupKFold(n_splits=self.n_splits)

        def objective(trial):
            params = {
                'n_estimators': trial.suggest_int('n_estimators', 30, 150),
                'max_depth': trial.suggest_int('max_depth', 2, 5),
                'learning_rate': trial.suggest_float('learning_rate', 0.01, 0.2, log=True),
                'subsample': trial.suggest_float('subsample', 0.6, 1.0),
                'colsample_bytree': trial.suggest_float('colsample_bytree', 0.6, 1.0),
                'min_child_weight': trial.suggest_int('min_child_weight', 1, 6),
                'gamma': trial.suggest_float('gamma', 0.0, 1.0),
                'reg_alpha': trial.suggest_float('reg_alpha', 1e-4, 1.0, log=True),
                'reg_lambda': trial.suggest_float('reg_lambda', 1e-4, 1.0, log=True),
                'random_state': self.random_state,
                'verbosity': 0
            }

            rmse_scores = []
            for train_idx, val_idx in gkf.split(X, y, groups=groups):
                X_tr, y_tr = X[train_idx], y[train_idx]
                X_va, y_va = X[val_idx], y[val_idx]

                reg = xgb.XGBRegressor(**params)
                reg.fit(X_tr, y_tr)
                preds = reg.predict(X_va)
                rmse = float(np.sqrt(mean_squared_error(y_va, preds)))
                rmse_scores.append(rmse)

            return float(np.mean(rmse_scores))

        study = optuna.create_study(direction="minimize")
        study.optimize(objective, n_trials=self.n_trials)

        return {
            'best_cv_rmse': float(study.best_value),
            'best_params': study.best_params,
            'n_trials': self.n_trials
        }
