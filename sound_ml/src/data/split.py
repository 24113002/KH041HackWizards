"""
SwasthAI Sound ML - Patient-Level Stratified Dataset Splitting
Guarantees 0% data leakage across patients (BP, DP, EP stay together).
"""

import os
import glob
import json
import re
import random
from collections import defaultdict, Counter
import numpy as np

def create_patient_stratified_split(
    labelled_dir: str,
    train_ratio: float = 0.70,
    val_ratio: float = 0.15,
    test_ratio: float = 0.15,
    seed: int = 42,
    output_split_file: str = "sound_ml/data/splits/patient_splits.json"
) -> dict:
    random.seed(seed)
    np.random.seed(seed)
    
    audio_dir = os.path.join(labelled_dir, "Audio Files") if os.path.exists(os.path.join(labelled_dir, "Audio Files")) else labelled_dir
    audio_files = sorted(glob.glob(os.path.join(audio_dir, "*.wav")))
    
    # Map patient ID -> list of audio files and primary label
    patients = defaultdict(lambda: {'files': [], 'diagnosis': '', 'sound_type': '', 'is_abnormal': 0})
    
    for p in audio_files:
        fname = os.path.basename(p)
        name_no_ext = os.path.splitext(fname)[0]
        match = re.match(r'([A-Z]+)(\d+)_(.*)', name_no_ext)
        if match:
            filter_mode = match.group(1)
            pat_num = int(match.group(2))
            tokens = [t.strip() for t in match.group(3).split(',')]
            diag = tokens[0] if len(tokens) > 0 else 'N'
            stype = tokens[1] if len(tokens) > 1 else 'N'
            
            # Binary: 0 = Normal, 1 = Abnormal/Pathological
            is_abn = 0 if diag.strip().upper() == 'N' else 1
            
            pat_id = f"P{pat_num}"
            patients[pat_id]['files'].append(p)
            patients[pat_id]['diagnosis'] = diag
            patients[pat_id]['sound_type'] = stype
            patients[pat_id]['is_abnormal'] = is_abn
            patients[pat_id]['patient_id'] = pat_id
            
    # Stratify by primary target (is_abnormal: Normal vs Pathological)
    normal_pats = [pid for pid, d in patients.items() if d['is_abnormal'] == 0]
    abnormal_pats = [pid for pid, d in patients.items() if d['is_abnormal'] == 1]
    
    random.shuffle(normal_pats)
    random.shuffle(abnormal_pats)
    
    def split_list(lst):
        n = len(lst)
        n_train = int(round(n * train_ratio))
        n_val = int(round(n * val_ratio))
        train = lst[:n_train]
        val = lst[n_train:n_train + n_val]
        test = lst[n_train + n_val:]
        return train, val, test
        
    train_norm, val_norm, test_norm = split_list(normal_pats)
    train_abn, val_abn, test_abn = split_list(abnormal_pats)
    
    train_pids = sorted(train_norm + train_abn)
    val_pids = sorted(val_norm + val_abn)
    test_pids = sorted(test_norm + test_abn)
    
    # Verify strict isolation
    assert set(train_pids).isdisjoint(set(val_pids)), "Data leakage between Train and Val!"
    assert set(train_pids).isdisjoint(set(test_pids)), "Data leakage between Train and Test!"
    assert set(val_pids).isdisjoint(set(test_pids)), "Data leakage between Val and Test!"
    
    def gather_records(pid_list):
        recs = []
        for pid in pid_list:
            for fpath in patients[pid]['files']:
                recs.append({
                    'patient_id': pid,
                    'file_path': os.path.abspath(fpath),
                    'file_name': os.path.basename(fpath),
                    'diagnosis': patients[pid]['diagnosis'],
                    'sound_type': patients[pid]['sound_type'],
                    'label': patients[pid]['is_abnormal']
                })
        return recs
        
    splits = {
        'metadata': {
            'total_subjects': len(patients),
            'train_subjects': len(train_pids),
            'val_subjects': len(val_pids),
            'test_subjects': len(test_pids),
            'seed': seed
        },
        'train_patient_ids': train_pids,
        'val_patient_ids': val_pids,
        'test_patient_ids': test_pids,
        'train': gather_records(train_pids),
        'val': gather_records(val_pids),
        'test': gather_records(test_pids)
    }
    
    os.makedirs(os.path.dirname(output_split_file), exist_ok=True)
    with open(output_split_file, 'w') as f:
        json.dump(splits, f, indent=2)
        
    print(f"=== PATIENT STRATIFIED SPLIT GENERATED ===")
    print(f"Train: {len(train_pids)} subjects ({len(splits['train'])} audio files)")
    print(f"Val:   {len(val_pids)} subjects ({len(splits['val'])} audio files)")
    print(f"Test:  {len(test_pids)} subjects ({len(splits['test'])} audio files)")
    print(f"Saved to: {output_split_file}")
    
    return splits

if __name__ == '__main__':
    create_patient_stratified_split(
        labelled_dir="dataset-lung sounds/labelled data",
        output_split_file="sound_ml/data/splits/patient_splits.json"
    )
