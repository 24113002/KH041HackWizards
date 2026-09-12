# SwasthAI — Offline COPD Risk Screening for Rural Healthcare

[![FastAPI](https://img.shields.io/badge/FastAPI-0.110+-009688.svg?style=flat&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B.svg?style=flat&logo=flutter&logoColor=white)](https://flutter.dev)
[![SQLite](https://img.shields.io/badge/SQLite-WAL_Mode-003B57.svg?style=flat&logo=sqlite&logoColor=white)](https://www.sqlite.org)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB.svg?style=flat&logo=python&logoColor=white)](https://www.python.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> **Team**: KH041 — HackWizards  
> **Challenge Track**: Healthcare & Rural Diagnostics  
> **Regulatory Notice**: *SwasthAI is an early screening-support aid for frontline health workers, NOT a diagnostic medical device.*

---

## 📌 Executive Summary

Chronic Obstructive Pulmonary Disease (COPD) is the third leading cause of death globally, disproportionately affecting rural agrarian populations exposed to biomass chulha smoke, occupational dust, and bidi smoking. In rural primary healthcare centers (PHCs), spirometry is rarely available due to cost, fragile hardware, and cloud dependency.

**SwasthAI** bridges this gap with a 100% offline-capable, handheld point-of-care screening ecosystem combining:
1. **IoT Screening Device (ESP32)**: Handheld unit capturing SpO₂, heart rate, exhalation breath pressure, and acoustic cough characteristics.
2. **Frontline Companion App (Flutter)**: Asha worker workflow guide for demographic intake, live sensor telemetry waveforms, and clinical questionnaire scoring.
3. **Local FastAPI & SQLite Engine**: Edge companion backend providing robust REST APIs, continuous bulk sensor storage, and multi-session screening tracking.

---

## 🏛️ System Architecture

![SwasthAI Architecture](docs/architecture.png)

```text
┌──────────────────────┐         BLE 5.0 GATT         ┌──────────────────────┐
│  ESP32 Edge Device   │ ───────────────────────────> │ Flutter Mobile App   │
│  - MAX30102 (SpO2/HR)│                              │ (Android Companion)  │
│  - Pressure Sensor   │                              │ - Offline SQLite DB  │
│  - Cough Microphone  │                              │ - Live Waveforms     │
└──────────────────────┘                              └──────────┬───────────┘
                                                                 │ HTTP REST
                                                                 │ (Localhost / WiFi)
                                                                 ▼
                                                      ┌──────────────────────┐
                                                      │ FastAPI Edge Backend │
                                                      │ - Python 3.12 / ORM  │
                                                      │ - Local SQLite (WAL) │
                                                      │ - 36 Pytest Tests    │
                                                      └──────────────────────┘
```

---

## 📂 Repository Structure

```text
KH041-HackWizards/
├── README.md                      # Primary project guide & documentation
├── LICENSE                        # MIT Open Source License
├── requirements.txt               # Backend Python dependency manifest
├── .gitignore                     # Git exclusion rules
│
├── src/                           # Complete Project Source Code
│   ├── backend/                   # FastAPI Backend & SQLite Data Layer
│   │   ├── app/                   # API routes, models, schemas, repos, services
│   │   ├── tests/                 # 36 automated unit & integration tests
│   │   ├── data/                  # SQLite runtime storage
│   │   ├── requirements.txt       # Backend dependencies
│   │   └── README.md              # Backend developer documentation
│   │
│   ├── frontend/                  # Flutter Android Companion Application
│   │   ├── lib/                   # Flutter UI, screens, BLE & database services
│   │   ├── android/               # Android native configuration
│   │   ├── pubspec.yaml           # Flutter package manifest
│   │   └── README.md              # Frontend developer documentation
│   │
│   └── hardware/                  # ESP32 C++ Arduino Firmware
│       ├── swasthai_esp32_firmware.ino
│       └── README.md              # Wiring & pinout documentation
│
├── docs/                          # Technical Architecture & Protocols
│   ├── project-documentation.md   # Full project design documentation
│   ├── architecture.png           # High-resolution architectural diagram
│   ├── architecture.md            # Mermaid component architecture
│   └── other-diagrams/            # Sequence and BLE protocol specifications
│
└── data/                          # Data Management & Storage
    └── README.md                  # Offline database architecture & privacy policy
```

---

## 🚀 Quick Start Guide

### 1. Backend Setup & Run (FastAPI + SQLite)

```bash
# Navigate to backend directory
cd src/backend

# Install dependencies
pip install -r requirements.txt

# Run the 36-test validation suite
pytest -v

# Start the offline API server
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```
- **Interactive Swagger Documentation**: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
- **ReDoc Technical Reference**: [http://127.0.0.1:8000/redoc](http://127.0.0.1:8000/redoc)
- **Health Endpoint**: [http://127.0.0.1:8000/health](http://127.0.0.1:8000/health)

### 2. Frontend Setup & Run (Flutter Companion)

```bash
# Navigate to frontend directory
cd src/frontend

# Install Flutter packages
flutter pub get

# Run on connected Android device or emulator
flutter run
```

### 3. Hardware Firmware (ESP32)
1. Open `src/hardware/swasthai_esp32_firmware.ino` in Arduino IDE or PlatformIO.
2. Install required libraries: `Wire`, `BLEDevice`, `BLEServer`, `BLEUtils`, `BLE2902`.
3. Select board: `ESP32 Dev Module` and flash the device.

---

## 📡 REST API Endpoint Summary

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` | Offline availability status check |
| `POST` | `/api/patients` | Register patient demographics |
| `GET` | `/api/patients` | Paginated patient profiles list |
| `GET` | `/api/patients/search?q={query}` | Local name search |
| `POST` | `/api/screenings` | Initiate point-of-care screening session |
| `POST` | `/api/screenings/{id}/complete` | Conclude session & timestamp |
| `GET` | `/api/screenings/{id}/complete` | Complete aggregate (Patient + Sensors + Questionnaire + Risk) |
| `POST` | `/api/screenings/{id}/sensor-data` | Ingest single sensor reading |
| `POST` | `/api/screenings/{id}/sensor-data/bulk` | Bulk insert continuous ESP32 sensor observations |
| `GET` | `/api/screenings/{id}/sensor-data/latest` | Retrieve latest sensor observation |
| `POST` | `/api/screenings/{id}/questionnaire` | Submit 8-point clinical symptom questionnaire |
| `PUT` | `/api/screenings/{id}/questionnaire` | Update existing questionnaire responses |
| `GET` | `/api/screenings/{id}/risk-result` | Retrieve risk screening outcome |
| `GET` | `/api/patients/{id}/screenings` | Patient longitudinal screening history |

---

## 🔒 Privacy, Security & Offline Guarantee

- **Zero Cloud Footprint**: Built from the ground up to operate in zero-connectivity remote villages.
- **Embedded SQLite WAL Engine**: Data stays locally encrypted and stored on the device with automated rollback safety.
- **Regulatory Transparency**: All outputs are framed under standard screening terminology (*"Risk Screening"*, *"Higher Risk"*, *"Clinical Evaluation Recommended"*).

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.