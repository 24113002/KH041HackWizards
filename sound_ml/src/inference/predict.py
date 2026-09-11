"""
SwasthAI Sound ML - Standalone Inference & Model Export CLI
"""

import os
import json
import argparse
import numpy as np
import torch
from ..models.cnn_model import RespiratoryCNN
from ..preprocessing.audio_transforms import load_audio_wav
from ..preprocessing.spectrogram import LogMelSpectrogramExtractor

class RespiratorySoundPredictor:
    def __init__(
        self,
        model_path: str = "sound_ml/models/sound_model_best.pt",
        labels_path: str = "sound_ml/models/labels.json",
        device: str = None
    ):
        self.device = torch.device(device if device else ('cuda' if torch.cuda.is_available() else 'cpu'))
        
        # Load Labels
        if os.path.exists(labels_path):
            with open(labels_path, 'r') as f:
                self.labels = json.load(f)
        else:
            self.labels = {'0': 'Normal', '1': 'Pathological_Respiratory_Sound'}
            
        # Load Model
        ckpt = torch.load(model_path, map_location=self.device, weights_only=False)
        hp = ckpt.get('hyperparameters', {})
        
        self.model = RespiratoryCNN(
            in_channels=1,
            num_classes=2,
            base_filters=hp.get('base_filters', 16),
            n_blocks=hp.get('n_blocks', 4),
            dropout_rate=0.0
        ).to(self.device)
        self.model.load_state_dict(ckpt['model_state_dict'])
        self.model.eval()
        
        self.extractor = LogMelSpectrogramExtractor(sample_rate=4000)
        
    def predict(self, audio_file_path: str) -> dict:
        if not os.path.exists(audio_file_path):
            return {
                'status': 'error',
                'error': f'File not found: {audio_file_path}'
            }
            
        try:
            audio = load_audio_wav(audio_file_path, target_sr=4000, target_duration_sec=5.0)
            wav_tensor = torch.from_numpy(audio).float()
            with torch.no_grad():
                spec = self.extractor(wav_tensor).to(self.device)
                logits = self.model(spec)
                probs = torch.softmax(logits, dim=1).cpu().numpy()[0]
                pred_idx = int(np.argmax(probs))
                confidence = float(probs[pred_idx])
                
            pred_class = self.labels.get(str(pred_idx), f"Class_{pred_idx}")
            
            return {
                'status': 'success',
                'file_name': os.path.basename(audio_file_path),
                'prediction': pred_class,
                'class_index': pred_idx,
                'confidence': round(confidence, 4),
                'probabilities': {
                    'normal': round(float(probs[0]), 4),
                    'pathological_adventitious': round(float(probs[1]), 4)
                },
                'model_version': 'SwasthAI_Sound_CNN_v1',
                'clinical_disclaimer': 'Research screening prototype. Not a diagnostic confirmation of COPD or other conditions.'
            }
        except Exception as e:
            return {
                'status': 'error',
                'error': str(e)
            }
            
    def export_torchscript(self, output_ts_path: str = "sound_ml/models/sound_model_scripted.pt"):
        dummy_input = torch.randn(1, 1, 64, 157, device=self.device)
        os.makedirs(os.path.dirname(output_ts_path), exist_ok=True)
        traced_model = torch.jit.trace(self.model, dummy_input)
        traced_model.save(output_ts_path)
        print(f"Exported TorchScript model to: {output_ts_path}")

    def export_onnx(self, output_onnx_path: str = "sound_ml/models/sound_model.onnx"):
        dummy_input = torch.randn(1, 1, 64, 157, device=self.device)
        os.makedirs(os.path.dirname(output_onnx_path), exist_ok=True)
        try:
            torch.onnx.export(
                self.model,
                dummy_input,
                output_onnx_path,
                input_names=['spectrogram'],
                output_names=['logits'],
                opset_version=18
            )
            print(f"Exported ONNX model to: {output_onnx_path}")
        except Exception as e:
            print(f"ONNX export notice: {e}. TorchScript is the primary mobile export.")

def main():
    parser = argparse.ArgumentParser(description="SwasthAI Respiratory Audio Inference CLI")
    parser.add_argument("--audio", type=str, required=True, help="Path to .wav respiratory audio recording")
    parser.add_argument("--model", type=str, default="sound_ml/models/sound_model_best.pt")
    parser.add_argument("--export_onnx", action="store_true", help="Export to ONNX format")
    args = parser.parse_args()
    
    predictor = RespiratorySoundPredictor(model_path=args.model)
    if args.export_onnx:
        predictor.export_onnx()
        
    result = predictor.predict(args.audio)
    print(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()
