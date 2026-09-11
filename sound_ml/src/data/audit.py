"""
SwasthAI Sound ML - Dataset Auditing Module
"""

import os
import glob
import wave
import json
import argparse
from collections import Counter, defaultdict

def audit_datasets(labelled_path: str, unlabelled_path: str, output_report: str = None) -> dict:
    results = {}
    
    # 1. Audit Labelled Dataset
    audio_dir = os.path.join(labelled_path, "Audio Files") if os.path.exists(os.path.join(labelled_path, "Audio Files")) else labelled_path
    wav_files_labelled = sorted(glob.glob(os.path.join(audio_dir, "*.wav")))
    
    labelled_sr = Counter()
    labelled_channels = Counter()
    labelled_durations = []
    patient_modes = defaultdict(dict)
    diagnoses = Counter()
    sound_types = Counter()
    
    for path in wav_files_labelled:
        fname = os.path.basename(path)
        try:
            with wave.open(path, 'rb') as wf:
                sr = wf.getframerate()
                ch = wf.getnchannels()
                dur = wf.getnframes() / float(sr) if sr > 0 else 0
                labelled_sr[sr] += 1
                labelled_channels[ch] += 1
                labelled_durations.append(dur)
        except Exception as e:
            continue
            
        name_no_ext = os.path.splitext(fname)[0]
        parts = name_no_ext.split('_')
        prefix = parts[0]
        # Extract filter mode (BP, DP, EP) and patient number
        mode = ''.join([c for c in prefix if c.isalpha()])
        pat_num = ''.join([c for c in prefix if c.isdigit()])
        
        if len(parts) > 1:
            tokens = [t.strip() for t in parts[1].split(',')]
            diag = tokens[0] if len(tokens) > 0 else 'Unknown'
            stype = tokens[1] if len(tokens) > 1 else 'Unknown'
            patient_modes[pat_num][mode] = fname
            if mode == 'BP' or not patient_modes[pat_num].get('diag'):
                patient_modes[pat_num]['diag'] = diag
                patient_modes[pat_num]['stype'] = stype
                diagnoses[diag] += 1
                sound_types[stype] += 1
                
    results['labelled'] = {
        'total_files': len(wav_files_labelled),
        'total_subjects': len(patient_modes),
        'sample_rates': dict(labelled_sr),
        'channels': dict(labelled_channels),
        'durations': {
            'min': min(labelled_durations) if labelled_durations else 0,
            'max': max(labelled_durations) if labelled_durations else 0,
            'mean': sum(labelled_durations)/len(labelled_durations) if labelled_durations else 0
        },
        'diagnoses_distribution': dict(diagnoses),
        'sound_types_distribution': dict(sound_types)
    }
    
    # 2. Audit Unlabelled Dataset
    wav_files_unlabelled = sorted(glob.glob(os.path.join(unlabelled_path, "*.wav")))
    unlabelled_sr = Counter()
    unlabelled_channels = Counter()
    unlabelled_durations = []
    unlabelled_subjects = set()
    
    for path in wav_files_unlabelled:
        fname = os.path.basename(path)
        try:
            with wave.open(path, 'rb') as wf:
                sr = wf.getframerate()
                ch = wf.getnchannels()
                dur = wf.getnframes() / float(sr) if sr > 0 else 0
                unlabelled_sr[sr] += 1
                unlabelled_channels[ch] += 1
                unlabelled_durations.append(dur)
        except Exception as e:
            continue
            
        parts = fname.split('_')
        if len(parts) >= 1:
            unlabelled_subjects.add(parts[0])
            
    results['unlabelled'] = {
        'total_files': len(wav_files_unlabelled),
        'total_subjects': len(unlabelled_subjects),
        'total_hours': sum(unlabelled_durations) / 3600.0 if unlabelled_durations else 0,
        'sample_rates': dict(unlabelled_sr),
        'channels': dict(unlabelled_channels),
        'durations': {
            'min': min(unlabelled_durations) if unlabelled_durations else 0,
            'max': max(unlabelled_durations) if unlabelled_durations else 0,
            'mean': sum(unlabelled_durations)/len(unlabelled_durations) if unlabelled_durations else 0
        }
    }
    
    print("=== DATASET AUDIT COMPLETE ===")
    print(f"Labelled Dataset: {results['labelled']['total_files']} files across {results['labelled']['total_subjects']} subjects.")
    print(f"Unlabelled Dataset: {results['unlabelled']['total_files']} files across {results['unlabelled']['total_subjects']} subjects ({results['unlabelled']['total_hours']:.2f} hrs).")
    
    if output_report:
        os.makedirs(os.path.dirname(output_report), exist_ok=True)
        with open(output_report, 'w') as f:
            json.dump(results, f, indent=2)
            
    return results

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="SwasthAI Dataset Audit")
    parser.add_argument("--labelled_path", type=str, default="dataset-lung sounds/labelled data")
    parser.add_argument("--unlabelled_path", type=str, default="dataset-lung sounds/unlabelled data")
    parser.add_argument("--output_report", type=str, default="sound_ml/outputs/reports/audit_summary.json")
    args = parser.parse_args()
    
    audit_datasets(args.labelled_path, args.unlabelled_path, args.output_report)
