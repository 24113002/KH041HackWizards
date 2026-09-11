"""
SwasthAI Fusion ML - Master Orchestration Runner
"""

from .data.dataset_builder import generate_multimodal_dataset
from .models.train import train_fusion_pipeline
from .evaluation.evaluate import evaluate_fusion

def main():
    print("=== EXECUTING SWASTHAI MULTIMODAL FUSION PIPELINE ===")
    
    # 1. Dataset Generation
    generate_multimodal_dataset(output_csv="fusion_ml/data/multimodal_fusion_dataset.csv", n_samples=600)

    # 2. Model Training & 8-Way Ablation Study
    train_fusion_pipeline(dataset_csv="fusion_ml/data/multimodal_fusion_dataset.csv", n_trials=25)

    # 3. Evaluation & Figures
    evaluate_fusion()

    print("\n=== MULTIMODAL FUSION PIPELINE COMPLETED SUCCESSFULLY ===")

if __name__ == "__main__":
    main()
