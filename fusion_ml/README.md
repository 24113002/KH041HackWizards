# SwasthAI: Multimodal Late-Fusion Risk Screening Model

Combines the outputs of:
1. SpO₂ & Optical PPG Model (`spo2_ml`)
2. Air-Pressure & Respiratory Mechanics Model (`air_pressure_ml`)
3. Cough & Lung-Sound Acoustic CNN (`sound_ml`)
4. COPD-PS Clinical Questionnaire

Produces an offline multi-class risk classification (`LOWER_RISK`, `MODERATE_RISK`, `HIGHER_RISK`), continuous composite risk index ($0–100$), and explainable contributing factors.

## Quickstart

```bash
# Run complete end-to-end fusion pipeline
python -m fusion_ml.src.run_pipeline

# Run automated unit test suite
python -m unittest fusion_ml/tests/test_fusion_pipeline.py
```
