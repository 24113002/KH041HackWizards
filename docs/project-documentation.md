# SwasthAI — Comprehensive Project Documentation

> **Offline COPD Risk Screening for Rural Healthcare**  
> **Team**: KH041 - HackWizards  
> **Notice**: *SwasthAI is a screening-support decision aid for frontline healthcare workers, NOT a diagnostic medical device.*

---

## 1. Executive Summary

Chronic Obstructive Pulmonary Disease (COPD) is the third leading cause of death worldwide, heavily impacting rural and agricultural communities in low-resource regions due to tobacco smoke, chulha (biomass fuel) emissions, and occupational dust. However, rural primary health centres (PHCs) lack trained pulmonologists, and conventional spirometry machines are costly, delicate, and require active internet connectivity.

**SwasthAI** solves this bottleneck with an end-to-end point-of-care screening ecosystem:
1. **IoT Screening Device (ESP32)**: Handheld hardware capturing SpO₂, heart rate (MAX30102), expiratory airway pressure (differential pressure sensor), and acoustic cough duration.
2. **Flutter Mobile Application**: Offline-first frontline companion app connecting to ESP32 over BLE, guiding Asha workers through a validated screening questionnaire and sensor protocol.
3. **Local FastAPI Backend & SQLite Engine**: Embedded offline backend providing standardized REST APIs, time-series sensor ingestion, and multi-session screening history with zero cloud dependencies.

---

## 2. System Architecture

```text
┌────────────────────────────────────────────────────────┐
│               ESP32 SENSOR HARDWARE                   │
│  - MAX30102: Optical SpO2 & Heart Rate                │
│  - Differential Pressure Transducer: Airway Pressure  │
│  - INMP441 Microphone: Acoustic Cough Activity        │
└──────────────────────────┬─────────────────────────────┘
                           │ Bluetooth Low Energy (BLE)
                           ▼
┌────────────────────────────────────────────────────────┐
│             FLUTTER MOBILE CLIENT (ANDROID)            │
│  - Asha Worker Guided Screening Workflow              │
│  - BLE Sensor Data Ingestion & Live Waveforms         │
│  - 8-Question Clinical Exposure Questionnaire         │
│  - Local SQLite Storage (Offline First)               │
└──────────────────────────┬─────────────────────────────┘
                           │ HTTP REST APIs (Localhost / Wi-Fi)
                           ▼
┌────────────────────────────────────────────────────────┐
│            FASTAPI BACKEND & ORM LAYER                 │
│  - Python 3.12 + FastAPI + Uvicorn                    │
│  - SQLAlchemy 2.0 ORM + Pydantic v2                   │
│  - Embedded SQLite Database (WAL Mode + Foreign Keys) │
│  - Pluggable Risk Assessment Service Engine           │
└────────────────────────────────────────────────────────┘
```

---

## 3. Core Modules & Directory Structure

```text
KH041-HackWizards/
├── README.md                  # Complete hackathon project overview & setup guide
├── LICENSE                    # MIT Open Source License
├── requirements.txt           # Python dependency manifest
├── .gitignore                 # Exclusion configuration
│
├── src/                       # Complete Project Source Code
│   ├── backend/               # FastAPI Backend & SQLite Database Layer
│   │   ├── app/               # Main application, models, schemas, repos, services
│   │   ├── tests/             # 36 automated unit & integration tests
│   │   └── data/              # SQLite data directory
│   ├── frontend/              # Flutter Mobile Application
│   │   ├── lib/               # Flutter screens, widgets, BLE & DB services
│   │   └── pubspec.yaml       # Dart dependencies
│   └── hardware/              # ESP32 C++ / Arduino Firmware
│       └── swasthai_esp32_firmware.ino
│
├── docs/                      # Architectural & Technical Documentation
│   ├── project-documentation.md
│   ├── architecture.png       # System architecture diagram
│   ├── architecture.md
│   └── other-diagrams/        # Detailed workflow and protocol diagrams
│
└── data/                      # Local storage specifications
    └── README.md
```

---

## 4. Screening Workflow & Methodology

1. **Patient Registration**: Frontline worker enters basic demographics (Age, Gender, Village, Smoking history).
2. **Physiological Capture**: ESP32 records 10-second steady-state SpO₂, pulse rate, and exhalation breath pressure.
3. **Questionnaire Protocol**: Collects pack-years, chulha smoke exposure, chronic cough, dyspnea, phlegm, and wheezing.
4. **Offline Assessment**: Combines physiological signals and clinical questionnaire scores into clear risk categories:
   - **Low Risk**: Regular health monitoring; lifestyle guidance.
   - **Moderate Risk**: Periodic follow-up; smoking cessation / clean cooking advisory.
   - **Higher Risk**: Priority referral to PHC / Taluka hospital for confirmatory spirometry.

---

## 5. Security, Privacy & Regulatory Compliance

- **No Remote Cloud Requirement**: Zero patient biometric or health data is transmitted over the public internet.
- **Offline Data Residency**: All screening data remains stored in local encrypted/isolated SQLite storage.
- **Medical Disclaimer**: Clear non-diagnostic disclaimer is displayed on all reports and screening results.
