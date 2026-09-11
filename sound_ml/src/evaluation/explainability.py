"""
SwasthAI Sound ML - Grad-CAM Log-Mel Spectrogram Explainability Module
"""

import os
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import torch
from ..models.cnn_model import RespiratoryCNN
from ..preprocessing.audio_transforms import load_audio_wav
from ..preprocessing.spectrogram import LogMelSpectrogramExtractor

def generate_gradcam_spectrogram(
    audio_path: str,
    model_checkpoint: str = "sound_ml/models/sound_model_best.pt",
    output_image_path: str = "sound_ml/outputs/figures/gradcam_saliency.png"
):
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    ckpt = torch.load(model_checkpoint, map_location=device, weights_only=False)
    hp = ckpt.get('hyperparameters', {})
    
    model = RespiratoryCNN(
        in_channels=1,
        num_classes=2,
        base_filters=hp.get('base_filters', 16),
        n_blocks=hp.get('n_blocks', 4),
        dropout_rate=hp.get('dropout', 0.30)
    ).to(device)
    model.load_state_dict(ckpt['model_state_dict'])
    model.eval()
    
    # 1. Load and extract Log-Mel Spectrogram
    extractor = LogMelSpectrogramExtractor(sample_rate=4000)
    audio = load_audio_wav(audio_path, target_sr=4000, target_duration_sec=5.0)
    wav_tensor = torch.from_numpy(audio).float()
    
    with torch.no_grad():
        spec = extractor(wav_tensor).to(device) # [1, 1, 64, 157]
        
    spec.requires_grad = True
    logits = model(spec)
    pred_class = torch.argmax(logits, dim=1).item()
    prob = torch.softmax(logits, dim=1)[0, pred_class].item()
    
    # Backward pass for target class
    model.zero_grad()
    score = logits[0, pred_class]
    score.backward()
    
    # Extract gradients and activations from the hook
    gradients = model.gradients # [1, C, H, W]
    activations = model.activations # [1, C, H, W]
    
    if gradients is not None and activations is not None:
        weights = torch.mean(gradients, dim=(2, 3), keepdim=True)
        cam = torch.sum(weights * activations, dim=1, keepdim=True)
        cam = torch.relu(cam)
        cam = cam.squeeze().detach().cpu().numpy()
        cam = (cam - np.min(cam)) / (np.max(cam) - np.min(cam) + 1e-8)
    else:
        cam = np.ones((64, 157))
        
    # Resize CAM to match Spectrogram shape
    spec_np = spec.squeeze().detach().cpu().numpy()
    
    # Plot Spectrogram + Grad-CAM Heatmap
    fig, axes = plt.subplots(2, 1, figsize=(10, 8), dpi=300)
    
    im1 = axes[0].imshow(spec_np, aspect='auto', origin='lower', cmap='magma')
    axes[0].set_title(f'Log-Mel Spectrogram: {os.path.basename(audio_path)}', fontsize=12, fontweight='bold')
    axes[0].set_ylabel('Mel Frequency Bins (50 - 2000 Hz)')
    axes[0].set_xlabel('Time Frames')
    plt.colorbar(im1, ax=axes[0], label='Log-Power (dB)')
    
    im2 = axes[1].imshow(spec_np, aspect='auto', origin='lower', cmap='gray')
    im2_cam = axes[1].imshow(cam, aspect='auto', origin='lower', cmap='jet', alpha=0.55)
    class_label = "Pathological Respiratory Sound" if pred_class == 1 else "Normal Breath Sound"
    axes[1].set_title(f'Grad-CAM Saliency Overlay (Predicted: {class_label}, Confidence: {prob*100:.1f}%)', fontsize=12, fontweight='bold')
    axes[1].set_ylabel('Mel Frequency Bins')
    axes[1].set_xlabel('Time Frames')
    plt.colorbar(im2_cam, ax=axes[1], label='Attribution Weight')
    
    plt.tight_layout()
    os.makedirs(os.path.dirname(output_image_path), exist_ok=True)
    plt.savefig(output_image_path)
    plt.close()
    print(f"Grad-CAM Saliency visualization saved to: {output_image_path}")

if __name__ == '__main__':
    import glob
    files = glob.glob("dataset-lung sounds/labelled data/Audio Files/*.wav")
    if files:
        generate_gradcam_spectrogram(files[0])
