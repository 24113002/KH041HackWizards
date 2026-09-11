# SwasthAI Architecture & Local-First Data Workflow

## Overview
SwasthAI is an **offline-first**, mobile health screening-support application designed for rural respiratory risk triage. The application operates entirely locally on-device without requiring internet connectivity, cloud authentication, FastAPI backend dependencies, or remote servers.

> **Medical Safety Disclaimer**: SwasthAI is a screening-support application, NOT a diagnostic medical device. Confirmatory clinical evaluation and spirometry may be required by qualified medical personnel.

---

## 1. Complete End-to-End Clinical Screening & Data Pipeline

```
Patient Selection / Registration
   │
   ▼
Start Screening Session (Unique Screening ID created)
   │
   ▼
ESP32 Hardware Sensor Acquisition (SwaasAI_ESP32)
   │ (GATT Service: 12345678-1234-1234-1234-1234567890AB)
   │ (Characteristic: 12345678-1234-1234-1234-1234567890AC [READ + NOTIFY])
   │ (CSV Packet: ID,AIRFLOW,SPO2,COUGH,RISK,STATUS)
   ▼
BleService ➔ SwaasAiPacketParser ➔ SwaasAiBleResult Model
   │
   ▼
COPD Screening Questionnaire (9 Questions + Comorbidities)
   │ (QuestionnaireController: validation, conditional non-smoker fields)
   ▼
Review Screening Information Screen
   │ (Patient Demographics + Questionnaire Answers + Sensor Observations)
   ▼
AssessmentController (Patient Safety & ID Isolation Verification)
   │
   ▼
Offline Risk Assessment Engine
   │ (Evaluates hardware score, status, questionnaire symptoms, contributing factors)
   ▼
Screening Result Experience (Complete or Incomplete Result Screen)
   │ (Risk Category Badge, Score /100, Contributing Factors, Recommendations, Disclaimer)
   ▼
Local Repository Layer (ScreeningRepository -> LocalScreeningRepository)
   │
   ▼
SQLite Database (sqflite / sqflite_common_ffi) ➔ Screening History & Details
```

---

## 2. Risk Assessment Responsibilities & Resolution

### Authoritative Risk Score & Status Rule:
1. **ESP32 Hardware Results**:
   - The ESP32 packet (`ID,AIRFLOW,SPO2,COUGH,RISK,STATUS`) delivers the hardware-calculated screening risk score (`0-100`) and screening status (`LOW`, `MODERATE`, `HIGH`, `INCOMPLETE`).
   - The Flutter frontend does NOT create a conflicting secondary algorithm that overrides or contradicts the hardware score.
2. **Questionnaire Clinical Context**:
   - The completed questionnaire provides clinical contributing factors (e.g. *Smoking history*, *Biomass smoke exposure*, *mMRC breathlessness grade*, *Chronic cough*, *Wheezing*).
   - Clinical recommendations are tailored to the combined risk category, smoking cessation needs, and biomass mitigation advice.
3. **Incomplete Results (`STATUS = INCOMPLETE` / `NA`)**:
   - Preserves `NA` strictly as `null` / `--`.
   - Never fabricates a 0 or fake score from missing data.
   - Screen displays `"Screening incomplete"` with missing items itemized and guidance to repeat measurement.
4. **Offline Local Engine**:
   - All assessment logic executes entirely on-device via `AssessmentController` and `RiskAssessmentEngine`.
   - Zero internet connection or cloud AI dependencies required.

---

## 3. Patient Safety & Data Isolation Architecture

To guarantee that patient data never mixes:
- A unique `ScreeningSession.id` is generated when starting a session and is bound strictly to `Patient.id`.
- Before running risk assessment, `AssessmentController` verifies that `patient.id` and `screeningId` match the active session.
- If a mismatch is detected, assessment is aborted immediately with `"Screening data does not match the selected patient."`

---

## 4. Hardware BLE Contract Specification

The application integrates with the official SwaasAI ESP32 hardware using the following contract:

| Parameter | Specification |
|---|---|
| **Device Name** | `SwaasAI_ESP32` |
| **Name Prefixes** | `SwaasAI`, `Swaas`, `SwasthAI`, `SWASTHAI`, `SWASTH` |
| **Service UUID** | `12345678-1234-1234-1234-1234567890AB` |
| **Characteristic UUID** | `12345678-1234-1234-1234-1234567890AC` |
| **GATT Properties** | `READ` + `NOTIFY` |
| **WRITE Property** | **NOT USED / NOT ALLOWED** |
| **Packet Format** | `ID,AIRFLOW,SPO2,COUGH,RISK,STATUS` (CSV comma separated) |

### Packet Fields:
1. `ID`: Screening/device record ID (e.g. `R01`). Must not be empty.
2. `AIRFLOW`: Raw airflow/pressure-derived sensor feature (e.g. `42350` or `NA`). Not calibrated clinical airflow.
3. `SPO2`: Blood oxygen saturation percentage (e.g. `97` or `NA`).
4. `COUGH`: Digital audio feature amplitude (e.g. `1860` or `NA`).
5. `RISK`: Calculated screening risk score `0-100` (e.g. `42` or `NA`).
6. `STATUS`: Final screening category: `LOW`, `MODERATE`, `HIGH`, `INCOMPLETE`.

---

## 5. Medical Safety & UI Design Rules
- **No Diagnostic Claims**: The application does not claim to diagnose COPD, asthma, or respiratory conditions.
- **Neutral Sensor Labeling**:
  - Raw Airflow: Labeled `"Raw Airflow Feature"`, accompanied by explanation `"Raw sensor-derived value; not calibrated clinical airflow."`
  - Cough: Labeled `"Cough Signal"`, accompanied by explanation `"Digital audio feature"`.
  - Heart Rate: The BLE packet does not transmit heart rate; the UI displays `--` without fabricating data.
