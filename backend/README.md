# SwasthAI — Offline COPD Risk Screening Backend

> **Offline COPD Risk Screening for Rural Healthcare**  
> *Note: SwasthAI is a screening-support system designed for rural frontline health workers, NOT a diagnostic medical device.*

---

## 1. Project Overview

SwasthAI is an edge-first, offline-capable screening-support platform for early COPD risk assessment in rural and remote settings. This backend operates locally on edge hardware or mobile companion environments alongside the Flutter Android mobile application.

---

## 2. Architecture & Tech Stack

### High-Level Architecture
```text
Flutter Android App
       │
       │ HTTP / REST API (Localhost / Wi-Fi Direct / Local Hotspot)
       ▼
 FastAPI Backend (Python 3.12)
       │
       ▼
 SQLite Database (Local Embedded Engine)
       ├── Patients
       ├── Screening Sessions
       ├── Sensor Readings
       ├── Questionnaires
       └── Risk Results
```

### Technology Stack
- **Framework**: FastAPI (Python 3.11+)
- **ASGI Server**: Uvicorn
- **Database / ORM**: SQLite + SQLAlchemy 2.0
- **Validation**: Pydantic v2
- **Testing**: Pytest + TestClient (in-memory SQLite test database)
- **Configuration**: Pydantic Settings + python-dotenv

---

## 3. Project Structure

```text
backend/
├── app/
│   ├── main.py                  # FastAPI entry point & lifespan
│   ├── seed.py                  # Demo / test data seed script
│   ├── core/
│   │   ├── config.py            # App settings & CORS config
│   │   └── database.py          # SQLite engine, session, & table init
│   ├── models/                  # SQLAlchemy ORM models
│   │   ├── patient.py
│   │   ├── screening.py
│   │   ├── sensor_reading.py
│   │   ├── questionnaire.py
│   │   └── risk_result.py
│   ├── schemas/                 # Pydantic v2 request/response schemas
│   │   ├── patient.py
│   │   ├── screening.py
│   │   ├── sensor.py
│   │   ├── questionnaire.py
│   │   └── risk_result.py
│   ├── repositories/            # Data access & persistence layer
│   │   ├── patient_repository.py
│   │   ├── screening_repository.py
│   │   ├── sensor_repository.py
│   │   └── questionnaire_repository.py
│   ├── services/                # Business logic & risk service interface
│   │   ├── patient_service.py
│   │   ├── screening_service.py
│   │   └── risk_service.py
│   └── api/
│       └── routes/              # Modular API endpoints
│           ├── health.py
│           ├── patients.py
│           ├── screenings.py
│           ├── sensors.py
│           └── questionnaire.py
├── tests/                       # Pytest test suite
│   ├── conftest.py
│   ├── test_health.py
│   ├── test_patients.py
│   ├── test_screenings.py
│   ├── test_sensors.py
│   └── test_questionnaire.py
├── docs/
│   └── API_CONTRACT.md          # Full frontend-backend API contract
├── data/                        # Local SQLite storage (git-ignored)
│   └── swasthai.db
├── requirements.txt
├── .env.example
├── .gitignore
└── README.md
```

---

## 4. Setup & Installation

### Prerequisites
- Python 3.11 or higher
- `pip`

### Step 1: Install Dependencies
```bash
cd backend
pip install -r requirements.txt
```

### Step 2: Environment Configuration (Optional)
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```

---

## 5. Running the Backend

### Start Server
```bash
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

### Seed Demo Data (Optional)
```bash
python -m app.seed
```

### Interactive API Documentation
Once running, view the interactive documentation:
- Swagger UI: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
- ReDoc: [http://127.0.0.1:8000/redoc](http://127.0.0.1:8000/redoc)

---

## 6. Running Tests

Run the full pytest suite (uses an isolated in-memory SQLite database):
```bash
pytest -v
```

---

## 7. Example API Requests

### 1. Health Check
```bash
curl http://127.0.0.1:8000/health
```

### 2. Register Patient
```bash
curl -X POST http://127.0.0.1:8000/api/patients \
  -H "Content-Type: application/json" \
  -d '{
    "full_name": "Rahul Patil",
    "age": 52,
    "gender": "Male",
    "village": "Satara",
    "occupation": "Farmer",
    "smoking_status": "former"
  }'
```

### 3. Start Screening Session
```bash
curl -X POST http://127.0.0.1:8000/api/screenings \
  -H "Content-Type: application/json" \
  -d '{"patient_id": 1}'
```

### 4. Record Sensor Reading
```bash
curl -X POST http://127.0.0.1:8000/api/screenings/1/sensor-readings \
  -H "Content-Type: application/json" \
  -d '{
    "spo2": 97.0,
    "heart_rate": 82.0,
    "pressure": 1.84,
    "cough_activity": 0.72
  }'
```

### 5. Submit Questionnaire
```bash
curl -X POST http://127.0.0.1:8000/api/screenings/1/questionnaire \
  -H "Content-Type: application/json" \
  -d '{
    "smoking_status": "former",
    "years_smoked": 25,
    "cigarettes_per_day": 10,
    "biomass_exposure": true,
    "breathlessness": true,
    "chronic_cough": true,
    "phlegm": false,
    "wheezing": true,
    "recurrent_respiratory_problems": false
  }'
```

### 6. Complete Screening
```bash
curl -X PUT http://127.0.0.1:8000/api/screenings/1/complete
```

---

## 8. Offline Architecture & Privacy

- **Fully Offline**: Zero reliance on external cloud APIs or active internet connections.
- **Embedded Storage**: SQLite database stored locally in `backend/data/swasthai.db`.
- **Privacy & Safety**: Minimal data collection, local storage isolation, input validation, and proper error handling without stack trace leaks.
