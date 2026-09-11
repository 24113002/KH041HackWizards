"""
SwasthAI Fusion ML - Optuna Multimodal Hyperparameter Tuner
Optimizes multi-class macro F1 score with subject-level GroupKFold cross-validation.
"""

import optuna
import numpy as np
import xgboost as xgb
from sklearn.model_selection import GroupKFold
from sklearn.metrics import f1_score

optuna.logging.set_verbosity(optuna.logging.WARNING)

class FusionOptunaTuner:
    def __init__(self, n_trials: int = 25, n_splits: int = 4, random_state: int = 42):
        self.n_trials = n_trials
        self.n_splits = n_splits
        self.random_state = random_state

    def tune(self, X: np.ndarray, y: np.ndarray, groups: np.ndarray) -> dict:
        gkf = GroupKFold(n_splits=self.n_splits)

        def objective(trial):
            params = {
                'objective': 'multi:softprob',
                'num_class': 3,
                'n_estimators': trial.suggest_int('n_estimators', 40, 150),
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

            f1_scores = []
            for train_idx, val_idx in gkf.split(X, y, groups=groups):
                X_tr, y_tr = X[train_idx], y[train_idx]
                X_va, y_va = X[val_idx], y[val_idx]

                clf = xgb.XGBClassifier(**params)
                clf.fit(X_tr, y_tr)
                preds = clf.predict(X_va)
                if preds.ndim > 1:
                    preds = np.argmax(preds, axis=1)
                score = float(f1_score(y_va, preds, average='macro'))
                f1_scores.append(score)

            return float(np.mean(f1_scores))

        study = optuna.create_study(direction="maximize")
        study.optimize(objective, n_trials=self.n_trials)

        return {
            'best_macro_f1': float(study.best_value),
            'best_params': study.best_params,
            'n_trials': self.n_trials
        }
