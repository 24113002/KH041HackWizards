# Data Directory — SwasthAI

## Offline-First Local Data Storage

SwasthAI is engineered as an **edge-first, offline-capable screening-support system** for rural healthcare workers.

### 1. Database Specifications
- **Engine**: SQLite 3 with Write-Ahead Logging (`PRAGMA journal_mode=WAL`)
- **Referential Integrity**: Enforced foreign keys (`PRAGMA foreign_keys=ON`)
- **Default Database File**: `swasthai.db` (auto-generated at runtime)
- **Location**: `src/backend/data/swasthai.db` (or `data/swasthai.db`)

### 2. Privacy & Data Protection
- **No Cloud Dependency**: Screening data remains 100% local on the screening device/companion laptop.
- **Git Policy**: All local database files (`*.db`, `*.sqlite`, `*.db-wal`, `*.db-shm`) are strictly **git-ignored** to ensure zero real patient data is ever committed to version control.
- **Data Models**:
  - `patients`: Patient demographic identifiers (Name, Age, Gender, Village, Occupation, Smoking Status).
  - `screening_sessions`: Session metadata, timestamps, and screening risk outcomes.
  - `sensor_readings`: Physiological observations (SpO₂, Heart Rate, Expiratory Pressure, Acoustic Cough Activity).
  - `questionnaire_responses`: Clinical COPD questionnaire symptoms and exposure history.
  - `risk_results`: Pluggable risk evaluation results and clinical guidance.

### 3. Demo / Seed Data
Demo datasets for hackathon evaluation utilize strictly fictional personas (e.g., Rahul Patil, Anita Sharma, Vijay More). Seed scripts are provided in `src/backend/app/seed.py`.
