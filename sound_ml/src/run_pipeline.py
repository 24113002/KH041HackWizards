"""
SwasthAI Sound ML - Full End-to-End Orchestration Runner
"""

import os
import sys
import glob
from sound_ml.src.data.audit import audit_datasets
from sound_ml.src.data.split import create_patient_stratified_split
from sound_ml.src.training.train_pretraining import train_unlabelled_autoencoder
from sound_ml.src.tuning.optimize import run_optuna_tuning
from sound_ml.src.training.train_final import train_model
from sound_ml.src.evaluation.evaluate import evaluate_all
from sound_ml.src.evaluation.explainability import generate_gradcam_spectrogram
from sound_ml.src.inference.predict import RespiratorySoundPredictor

def run_full_pipeline(
    labelled_dir: str = "dataset-lung sounds/labelled data",
    unlabelled_dir: str = "dataset-lung sounds/unlabelled data",
    epochs: int = 35,
    tune: bool = True
):
    print("="*70)
    print("SWASTHAI RESPIRATORY SOUND ML PIPELINE (PyTorch)")
    print("="*70)
    
    # 1. Audit
    print("\n[STEP 1/6] Auditing Datasets...")
    audit_datasets(labelled_dir, unlabelled_dir, output_report="sound_ml/outputs/reports/audit_summary.json")
    
    # 2. Patient-Stratified Split (0% Patient Leakage)
    print("\n[STEP 2/6] Generating Patient-Stratified Split...")
    splits_file = "sound_ml/data/splits/patient_splits.json"
    create_patient_stratified_split(labelled_dir, output_split_file=splits_file)
    
    # 3. Self-Supervised Pretraining on Dataset 2
    print("\n[STEP 3/6] Self-Supervised Masked Autoencoder Pretraining on Unlabelled Dataset 2...")
    pretrained_ckpt = "sound_ml/models/pretrained_autoencoder.pt"
    train_unlabelled_autoencoder(unlabelled_dir, epochs=5, output_checkpoint=pretrained_ckpt)
    
    # 4. Optuna Hyperparameter Optimization
    best_params = {}
    if tune:
        print("\n[STEP 4/6] Running Optuna Hyperparameter Tuning...")
        best_params = run_optuna_tuning(splits_file, n_trials=8, epochs_per_trial=10)
    else:
        best_params = {'base_filters': 16, 'n_blocks': 4, 'dropout': 0.30, 'lr': 0.001, 'weight_decay': 1e-4}
        
    # 5. Final PyTorch Model Training & Loss Curve Logging
    print("\n[STEP 5/6] Final Model Training with Pretrained Weights & Best Hyperparameters...")
    model, history, best_val_f1 = train_model(
        splits_file=splits_file,
        pretrained_weights_path=pretrained_ckpt,
        epochs=epochs,
        batch_size=best_params.get('batch_size', 16),
        lr=best_params.get('lr', 0.001),
        weight_decay=best_params.get('weight_decay', 1e-4),
        base_filters=best_params.get('base_filters', 16),
        n_blocks=best_params.get('n_blocks', 4),
        dropout=best_params.get('dropout', 0.30)
    )
    
    # 6. Evaluation, Loss Progression Graph Plotting & Explainability
    print("\n[STEP 6/6] Evaluating & Generating Performance & Loss Curves...")
    evaluate_all(splits_file=splits_file)
    
    # Generate Grad-CAM Explainability
    test_files = glob.glob(os.path.join(labelled_dir, "Audio Files", "*.wav"))
    if test_files:
        generate_gradcam_spectrogram(test_files[0])
        
    # Export Mobile Models (TorchScript + ONNX)
    print("\nExporting mobile deployment models (TorchScript & ONNX)...")
    predictor = RespiratorySoundPredictor()
    predictor.export_torchscript("sound_ml/models/sound_model_scripted.pt")
    predictor.export_onnx("sound_ml/models/sound_model.onnx")
    
    print("\n" + "="*70)
    print("ALL PIPELINE STAGES COMPLETED SUCCESSFULLY!")
    print("="*70)

if __name__ == '__main__':
    run_full_pipeline(epochs=30, tune=True)
