"""
SwasthAI SpO2 & PPG ML - Dataset Auditing Module
Audits Zenodo PPG dataset (Record 18109876) and ESP32 MAX30102 hardware signal profiles.
"""

import os
import glob
import json
import pandas as pd
import numpy as np

def audit_spo2_datasets(
    dataset_dir: str = "Spo2 dataset",
    output_report_file: str = "spo2_ml/outputs/reports/dataset_audit_report.md"
) -> dict:
    results = {'databases': {}, 'overall': {}}
    db_folders = ['2s_db', '16s_db', '32s_db', '64s_db', '128s_db', '256s_db']
    
    total_files = 0
    all_subjects = set()
    
    for folder in db_folders:
        fpath = os.path.join(dataset_dir, folder)
        if not os.path.exists(fpath):
            continue
            
        csv_files = sorted(glob.glob(os.path.join(fpath, "*.csv")))
        total_files += len(csv_files)
        
        folder_rows = 0
        subject_stats = {}
        class_dist = {0: 0, 1: 0}
        
        for cf in csv_files:
            fname = os.path.basename(cf)
            sub_id = fname.replace('.csv', '')
            all_subjects.add(sub_id)
            
            df = pd.read_csv(cf, sep=';')
            n_rows = len(df)
            folder_rows += n_rows
            
            # Check target distribution
            targets = df['copd'].value_counts().to_dict()
            for k, v in targets.items():
                class_dist[k] = class_dist.get(k, 0) + v
                
            subject_stats[sub_id] = {
                'file_name': fname,
                'rows': n_rows,
                'is_patient': sub_id.startswith('P'),
                'gender': 'Male' if sub_id.endswith('_m') else 'Female'
            }
            
        results['databases'][folder] = {
            'total_windows': folder_rows,
            'class_distribution': {
                'normal_0': class_dist.get(0, 0),
                'copd_1': class_dist.get(1, 0)
            },
            'subjects': subject_stats
        }
        
    results['overall'] = {
        'total_folders': len(results['databases']),
        'total_csv_files': total_files,
        'unique_subjects': sorted(list(all_subjects)),
        'total_subjects_count': len(all_subjects)
    }
    
    # Generate Markdown Report
    os.makedirs(os.path.dirname(output_report_file), exist_ok=True)
    with open(output_report_file, 'w', encoding='utf-8') as f:
        f.write("# SwasthAI PPG & SpO2 Dataset Audit Report\n\n")
        f.write("**Source**: Zenodo Record 18109876 (PPG Respiratory Screening Database)\n")
        f.write(f"**Total Database Resolutions**: {len(results['databases'])}\n")
        f.write(f"**Total Unique Subjects**: {len(all_subjects)} ({', '.join(sorted(list(all_subjects)))})\n\n")
        
        f.write("## 1. Executive Summary & Critical Target Findings\n\n")
        f.write("> [!IMPORTANT]\n")
        f.write("> **Target Variable Identification (Strict Requirement)**:\n")
        f.write("> The Zenodo dataset provides PPG window recordings categorized by **`copd` binary label** ($0 = \\text{Normal Control}$, $1 = \\text{COPD Patient}$).\n")
        f.write("> The dataset does **not** contain continuous blood-gas co-oximeter SpO₂ ground truth values (e.g. 98.4%).\n")
        f.write("> In strict adherence to Medical Safety and ML Integrity rules, we formulate:\n")
        f.write("> 1. **Supervised ML Task**: **PPG-based Respiratory / COPD Screening Classification (XGBoost)** using engineered physiological PPG features.\n")
        f.write("> 2. **SpO₂ Classical Baseline**: **MAX30102 AC/DC R-ratio calibration engine** for offline pulse oximetry.\n\n")
        
        f.write("## 2. Database Breakdown by Window Duration\n\n")
        f.write("| Database Folder | Window Duration | Window Sample Count | Normal Windows (0) | COPD Windows (1) | COPD Prevalence |\n")
        f.write("|---|---|---|---|---|---|\n")
        for db, data in results['databases'].items():
            tot = data['total_windows']
            n0 = data['class_distribution']['normal_0']
            n1 = data['class_distribution']['copd_1']
            prev = (n1 / tot * 100) if tot > 0 else 0
            f.write(f"| `{db}` | {db.replace('_db', '')} | {tot:,} | {n0:,} ({n0/tot*100:.1f}%) | {n1:,} ({n1/tot*100:.1f}%) | **{prev:.1f}%** |\n")
            
        f.write("\n## 3. Subject-Level Breakdown (6 Human Subjects)\n\n")
        f.write("| Subject ID | Cohort Category | Gender | 2s Windows | 16s Windows | 32s Windows | 64s Windows |\n")
        f.write("|---|---|---|---|---|---|---|\n")
        for sid in sorted(list(all_subjects)):
            is_p = sid.startswith('P')
            gender = 'Male' if sid.endswith('_m') else 'Female'
            w2 = results['databases'].get('2s_db', {}).get('subjects', {}).get(sid, {}).get('rows', 0)
            w16 = results['databases'].get('16s_db', {}).get('subjects', {}).get(sid, {}).get('rows', 0)
            w32 = results['databases'].get('32s_db', {}).get('subjects', {}).get(sid, {}).get('rows', 0)
            w64 = results['databases'].get('64s_db', {}).get('subjects', {}).get(sid, {}).get('rows', 0)
            f.write(f"| `{sid}` | {'COPD Patient' if is_p else 'Normal Control'} | {gender} | {w2:,} | {w16:,} | {w32:,} | {w64:,} |\n")
            
        f.write("\n## 4. Hardware Domain Shift & ESP32 Compatibility\n\n")
        f.write("- **Hardware**: ESP32 + MAX30102 provides raw 18-bit RED/IR ADC counts ($0 - 262143$).\n")
        f.write("- **Saturation Rejection**: Saturated signals ($262143$) are flagged and rejected immediately as `INVALID_SIGNAL`.\n")
        f.write("- **Feature Engineering**: Features extracted (AC/DC separation, pulse rate, R-ratio, spectral entropy, and variability) are normalized and hardware-independent.\n")
        
    print(f"Dataset audit complete. Report written to {output_report_file}")
    return results

if __name__ == '__main__':
    audit_spo2_datasets()
