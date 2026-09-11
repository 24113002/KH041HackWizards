# SwasthAI PPG & SpO2 Dataset Audit Report

**Source**: Zenodo Record 18109876 (PPG Respiratory Screening Database)
**Total Database Resolutions**: 6
**Total Unique Subjects**: 7 (N-06_m, N_05_m, N_06_m, P_01_f, P_02_f, P_03_m, P_04_m)

## 1. Executive Summary & Critical Target Findings

> [!IMPORTANT]
> **Target Variable Identification (Strict Requirement)**:
> The Zenodo dataset provides PPG window recordings categorized by **`copd` binary label** ($0 = \text{Normal Control}$, $1 = \text{COPD Patient}$).
> The dataset does **not** contain continuous blood-gas co-oximeter SpO₂ ground truth values (e.g. 98.4%).
> In strict adherence to Medical Safety and ML Integrity rules, we formulate:
> 1. **Supervised ML Task**: **PPG-based Respiratory / COPD Screening Classification (XGBoost)** using engineered physiological PPG features.
> 2. **SpO₂ Classical Baseline**: **MAX30102 AC/DC R-ratio calibration engine** for offline pulse oximetry.

## 2. Database Breakdown by Window Duration

| Database Folder | Window Duration | Window Sample Count | Normal Windows (0) | COPD Windows (1) | COPD Prevalence |
|---|---|---|---|---|---|
| `2s_db` | 2s | 245,688 | 78,491 (31.9%) | 167,197 (68.1%) | **68.1%** |
| `16s_db` | 16s | 30,708 | 9,810 (31.9%) | 20,898 (68.1%) | **68.1%** |
| `32s_db` | 32s | 15,354 | 4,905 (31.9%) | 10,449 (68.1%) | **68.1%** |
| `64s_db` | 64s | 7,676 | 2,452 (31.9%) | 5,224 (68.1%) | **68.1%** |
| `128s_db` | 128s | 3,836 | 1,225 (31.9%) | 2,611 (68.1%) | **68.1%** |
| `256s_db` | 256s | 1,916 | 612 (31.9%) | 1,304 (68.1%) | **68.1%** |

## 3. Subject-Level Breakdown (6 Human Subjects)

| Subject ID | Cohort Category | Gender | 2s Windows | 16s Windows | 32s Windows | 64s Windows |
|---|---|---|---|---|---|---|
| `N-06_m` | Normal Control | Male | 0 | 3,604 | 0 | 0 |
| `N_05_m` | Normal Control | Male | 49,652 | 6,206 | 3,103 | 1,551 |
| `N_06_m` | Normal Control | Male | 28,839 | 0 | 1,802 | 901 |
| `P_01_f` | COPD Patient | Female | 36,673 | 4,584 | 2,292 | 1,146 |
| `P_02_f` | COPD Patient | Female | 56,871 | 7,108 | 3,554 | 1,777 |
| `P_03_m` | COPD Patient | Male | 40,129 | 5,016 | 2,508 | 1,254 |
| `P_04_m` | COPD Patient | Male | 33,524 | 4,190 | 2,095 | 1,047 |

## 4. Hardware Domain Shift & ESP32 Compatibility

- **Hardware**: ESP32 + MAX30102 provides raw 18-bit RED/IR ADC counts ($0 - 262143$).
- **Saturation Rejection**: Saturated signals ($262143$) are flagged and rejected immediately as `INVALID_SIGNAL`.
- **Feature Engineering**: Features extracted (AC/DC separation, pulse rate, R-ratio, spectral entropy, and variability) are normalized and hardware-independent.
