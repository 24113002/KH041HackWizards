# SwasthAI Backend API Contract (v0.3.0 - Phase B3)

> **IMPORTANT MEDICAL & REGULATORY NOTICE**:  
> SwasthAI is an offline screening-support system designed for rural frontline healthcare workers. It is **NOT** a diagnostic medical device and does **NOT** provide a definitive medical diagnosis of COPD.

---

## Base URL
- Local Development Default: `http://127.0.0.1:8000`
- API Prefix: `/api`
- OpenAPI Specification: `/openapi.json`
- Interactive Swagger UI: `/docs`
- ReDoc: `/redoc`

---

## 1. System & Health

### `GET /`
Service metadata, version, offline status, and documentation links.

- **Response `200 OK`**:
  ```json
  {
    "service": "SwasthAI Backend",
    "version": "0.1.0",
    "mode": "offline",
    "status": "online",
    "docs": "/docs",
    "redoc": "/redoc",
    "health": "/health",
    "api_prefix": "/api"
  }
  ```

---

### `GET /health`
Verify that the local offline backend is operational.

- **Response `200 OK`**:
  ```json
  {
    "status": "ok",
    "service": "SwasthAI Backend",
    "mode": "offline"
  }
  ```

---

## 2. Patient Management

### `POST /api/patients`
Register a new patient profile.

- **Request Body (`application/json`)**:
  ```json
  {
    "full_name": "Rahul Patil",
    "age": 52,
    "gender": "Male",
    "village": "Satara",
    "occupation": "Farmer",
    "smoking_status": "Former Smoker"
  }
  ```
- **Response `201 Created`**:
  ```json
  {
    "id": 1,
    "full_name": "Rahul Patil",
    "age": 52,
    "gender": "Male",
    "village": "Satara",
    "occupation": "Farmer",
    "smoking_status": "Former Smoker",
    "created_at": "2026-09-11T14:30:00Z",
    "updated_at": "2026-09-11T14:30:00Z"
  }
  ```
- **Errors**:
  - `422 Unprocessable Content`: Validation failure (e.g. invalid age or missing required fields).

---

### `GET /api/patients`
Retrieve a paginated list of patients.

- **Query Parameters**:
  - `skip` (int, default: `0`)
  - `limit` (int, default: `100`, max: `500`)
- **Response `200 OK`**:
  ```json
  [
    {
      "id": 1,
      "full_name": "Rahul Patil",
      "age": 52,
      "gender": "Male",
      "village": "Satara",
      "occupation": "Farmer",
      "smoking_status": "Former Smoker",
      "created_at": "2026-09-11T14:30:00Z",
      "updated_at": "2026-09-11T14:30:00Z"
    }
  ]
  ```

---

### `GET /api/patients/search?q={query}`
Search patients by name locally.

- **Query Parameters**:
  - `q` (string, required): Search substring
- **Response `200 OK`**:
  ```json
  [
    {
      "id": 1,
      "full_name": "Rahul Patil",
      "age": 52,
      "gender": "Male",
      "village": "Satara",
      "occupation": "Farmer",
      "smoking_status": "Former Smoker",
      "created_at": "2026-09-11T14:30:00Z",
      "updated_at": "2026-09-11T14:30:00Z"
    }
  ]
  ```

---

### `GET /api/patients/{patient_id}`
Retrieve a single patient by ID.

- **Path Parameters**:
  - `patient_id` (integer)
- **Response `200 OK`**:
  ```json
  {
    "id": 1,
    "full_name": "Rahul Patil",
    "age": 52,
    "gender": "Male",
    "village": "Satara",
    "occupation": "Farmer",
    "smoking_status": "Former Smoker",
    "created_at": "2026-09-11T14:30:00Z",
    "updated_at": "2026-09-11T14:30:00Z"
  }
  ```
- **Errors**:
  - `404 Not Found`: Patient does not exist.

---

### `PUT /api/patients/{patient_id}`
Update patient information.

- **Path Parameters**:
  - `patient_id` (integer)
- **Request Body (`application/json`)**:
  ```json
  {
    "age": 53,
    "occupation": "Senior Farmer"
  }
  ```
- **Response `200 OK`**:
  ```json
  {
    "id": 1,
    "full_name": "Rahul Patil",
    "age": 53,
    "gender": "Male",
    "village": "Satara",
    "occupation": "Senior Farmer",
    "smoking_status": "Former Smoker",
    "created_at": "2026-09-11T14:30:00Z",
    "updated_at": "2026-09-11T14:35:00Z"
  }
  ```
- **Errors**:
  - `404 Not Found`: Patient does not exist.
  - `422 Unprocessable Content`: Validation failure.

---

### `DELETE /api/patients/{patient_id}`
Delete a patient and cascade delete associated screening sessions safely.

- **Path Parameters**:
  - `patient_id` (integer)
- **Response `204 No Content`**
- **Errors**:
  - `404 Not Found`: Patient does not exist.

---

### `GET /api/patients/{patient_id}/screenings`
List all screening sessions conducted for a specific patient, sorted newest first.

- **Path Parameters**:
  - `patient_id` (integer)
- **Response `200 OK`**:
  ```json
  [
    {
      "id": 101,
      "patient_id": 1,
      "started_at": "2026-09-11T14:40:00Z",
      "completed_at": null,
      "status": "in_progress",
      "risk_score": null,
      "risk_category": null
    }
  ]
  ```
- **Errors**:
  - `404 Not Found`: Patient does not exist.

---

## 3. Screening Sessions

### `POST /api/screenings`
Start a new screening session for a registered patient.

- **Request Body (`application/json`)**:
  ```json
  {
    "patient_id": 1
  }
  ```
- **Response `201 Created`**:
  ```json
  {
    "id": 101,
    "patient_id": 1,
    "started_at": "2026-09-11T14:40:00Z",
    "completed_at": null,
    "status": "in_progress",
    "risk_score": null,
    "risk_category": null
  }
  ```
- **Errors**:
  - `404 Not Found`: Patient ID does not exist.

---

### `GET /api/screenings`
Retrieve screening history across all patients.

- **Query Parameters**:
  - `skip` (int, default: `0`)
  - `limit` (int, default: `100`, max: `500`)
- **Response `200 OK`**:
  ```json
  [
    {
      "id": 101,
      "patient_id": 1,
      "started_at": "2026-09-11T14:40:00Z",
      "completed_at": null,
      "status": "in_progress",
      "risk_score": null,
      "risk_category": null
    }
  ]
  ```

---

### `GET /api/screenings/{screening_id}`
Retrieve screening session details including sensor readings and questionnaire.

- **Path Parameters**:
  - `screening_id` (integer)
- **Response `200 OK`**:
  ```json
  {
    "id": 101,
    "patient_id": 1,
    "started_at": "2026-09-11T14:40:00Z",
    "completed_at": "2026-09-11T14:45:00Z",
    "status": "completed",
    "risk_score": null,
    "risk_category": null,
    "sensor_readings": [],
    "questionnaire_response": null,
    "risk_result": null
  }
  ```
- **Errors**:
  - `404 Not Found`: Screening session not found.

---

### `POST /api/screenings/{screening_id}/complete` & `PUT /api/screenings/{screening_id}/complete`
Mark a screening session as completed and timestamp it.

- **Path Parameters**:
  - `screening_id` (integer)
- **Response `200 OK`**:
  ```json
  {
    "id": 101,
    "patient_id": 1,
    "started_at": "2026-09-11T14:40:00Z",
    "completed_at": "2026-09-11T14:45:00Z",
    "status": "completed",
    "risk_score": null,
    "risk_category": null
  }
  ```
- **Errors**:
  - `404 Not Found`: Screening session not found.

---

### `GET /api/screenings/{screening_id}/complete`
Retrieve complete screening aggregation (Patient Demographics, Screening Session, Time-series Sensor Readings, Questionnaire, Risk Result) for the Flutter Details screen.

- **Path Parameters**:
  - `screening_id` (integer)
- **Response `200 OK`**:
  ```json
  {
    "patient": {
      "id": 1,
      "full_name": "Rahul Patil",
      "age": 52,
      "gender": "Male",
      "village": "Satara",
      "occupation": "Farmer",
      "smoking_status": "Former Smoker",
      "created_at": "2026-09-11T14:30:00Z",
      "updated_at": "2026-09-11T14:30:00Z"
    },
    "screening": {
      "id": 101,
      "patient_id": 1,
      "started_at": "2026-09-11T14:40:00Z",
      "completed_at": "2026-09-11T14:45:00Z",
      "status": "completed",
      "risk_score": null,
      "risk_category": null
    },
    "sensor_readings": [
      {
        "id": 1,
        "screening_id": 101,
        "timestamp": "2026-09-11T14:41:00Z",
        "spo2": 96.0,
        "heart_rate": 78.0,
        "pressure": 0.42,
        "cough_activity": 0.15
      }
    ],
    "questionnaire": {
      "id": 1,
      "screening_id": 101,
      "smoking_status": "former",
      "years_smoked": 20,
      "cigarettes_per_day": 8,
      "biomass_exposure": true,
      "breathlessness": true,
      "chronic_cough": true,
      "phlegm": false,
      "wheezing": true,
      "recurrent_respiratory_problems": false,
      "created_at": "2026-09-11T14:42:00Z"
    },
    "risk_result": null
  }
  ```
- **Errors**:
  - `404 Not Found`: Screening session not found.

---

## 4. Sensor Data APIs

### `POST /api/screenings/{screening_id}/sensor-data`
Store an individual sensor observation.

- **Path Parameters**:
  - `screening_id` (integer)
- **Request Body (`application/json`)**:
  ```json
  {
    "timestamp": "2026-09-11T10:30:00Z",
    "spo2": 96.0,
    "heart_rate": 78.0,
    "pressure": 0.42,
    "cough_activity": 0.15
  }
  ```
- **Response `201 Created`**:
  ```json
  {
    "id": 1,
    "screening_id": 101,
    "timestamp": "2026-09-11T10:30:00Z",
    "spo2": 96.0,
    "heart_rate": 78.0,
    "pressure": 0.42,
    "cough_activity": 0.15
  }
  ```

---

### `POST /api/screenings/{screening_id}/sensor-data/bulk`
Bulk insert multiple continuous readings from the ESP32 in a single transaction.

- **Path Parameters**:
  - `screening_id` (integer)
- **Request Body (`application/json`)**:
  ```json
  {
    "readings": [
      {
        "timestamp": "2026-09-11T10:30:00Z",
        "spo2": 96.0,
        "heart_rate": 78.0,
        "pressure": 0.42,
        "cough_activity": 0.10
      },
      {
        "timestamp": "2026-09-11T10:30:01Z",
        "spo2": 95.8,
        "heart_rate": 79.0,
        "pressure": 0.45,
        "cough_activity": 0.20
      }
    ]
  }
  ```
- **Response `201 Created`**:
  ```json
  [
    {
      "id": 1,
      "screening_id": 101,
      "timestamp": "2026-09-11T10:30:00Z",
      "spo2": 96.0,
      "heart_rate": 78.0,
      "pressure": 0.42,
      "cough_activity": 0.10
    },
    {
      "id": 2,
      "screening_id": 101,
      "timestamp": "2026-09-11T10:30:01Z",
      "spo2": 95.8,
      "heart_rate": 79.0,
      "pressure": 0.45,
      "cough_activity": 0.20
    }
  ]
  ```

---

### `GET /api/screenings/{screening_id}/sensor-data`
Retrieve all recorded sensor data for a screening session, ordered chronologically.

- **Path Parameters**:
  - `screening_id` (integer)
- **Response `200 OK`**:
  ```json
  [
    {
      "id": 1,
      "screening_id": 101,
      "timestamp": "2026-09-11T10:30:00Z",
      "spo2": 96.0,
      "heart_rate": 78.0,
      "pressure": 0.42,
      "cough_activity": 0.15
    }
  ]
  ```

---

### `GET /api/screenings/{screening_id}/sensor-data/latest`
Retrieve the most recent sensor reading for a screening session.

- **Path Parameters**:
  - `screening_id` (integer)
- **Response `200 OK`**:
  ```json
  {
    "id": 1,
    "screening_id": 101,
    "timestamp": "2026-09-11T10:30:00Z",
    "spo2": 96.0,
    "heart_rate": 78.0,
    "pressure": 0.42,
    "cough_activity": 0.15
  }
  ```
- **Errors**:
  - `404 Not Found`: No sensor readings exist for this screening.

---

## 5. Questionnaire APIs

### `POST /api/screenings/{screening_id}/questionnaire`
Submit clinical questionnaire responses for a screening session.

- **Path Parameters**:
  - `screening_id` (integer)
- **Request Body (`application/json`)**:
  ```json
  {
    "smoking_status": "former",
    "years_smoked": 25,
    "cigarettes_per_day": 10,
    "biomass_exposure": true,
    "breathlessness": true,
    "chronic_cough": true,
    "phlegm": false,
    "wheezing": true,
    "recurrent_respiratory_problems": false
  }
  ```
- **Response `201 Created`**:
  ```json
  {
    "id": 1,
    "screening_id": 101,
    "smoking_status": "former",
    "years_smoked": 25,
    "cigarettes_per_day": 10,
    "biomass_exposure": true,
    "breathlessness": true,
    "chronic_cough": true,
    "phlegm": false,
    "wheezing": true,
    "recurrent_respiratory_problems": false,
    "created_at": "2026-09-11T14:42:00Z"
  }
  ```

---

### `GET /api/screenings/{screening_id}/questionnaire`
Retrieve questionnaire responses for a screening session.

- **Path Parameters**:
  - `screening_id` (integer)
- **Response `200 OK`**:
  ```json
  {
    "id": 1,
    "screening_id": 101,
    "smoking_status": "former",
    "years_smoked": 25,
    "cigarettes_per_day": 10,
    "biomass_exposure": true,
    "breathlessness": true,
    "chronic_cough": true,
    "phlegm": false,
    "wheezing": true,
    "recurrent_respiratory_problems": false,
    "created_at": "2026-09-11T14:42:00Z"
  }
  ```
- **Errors**:
  - `404 Not Found`: Questionnaire has not been submitted for this screening.

---

### `PUT /api/screenings/{screening_id}/questionnaire`
Update existing questionnaire responses.

- **Path Parameters**:
  - `screening_id` (integer)
- **Request Body (`application/json`)**:
  ```json
  {
    "years_smoked": 30,
    "cigarettes_per_day": 15
  }
  ```
- **Response `200 OK`**:
  ```json
  {
    "id": 1,
    "screening_id": 101,
    "smoking_status": "former",
    "years_smoked": 30,
    "cigarettes_per_day": 15,
    "biomass_exposure": true,
    "breathlessness": true,
    "chronic_cough": true,
    "phlegm": false,
    "wheezing": true,
    "recurrent_respiratory_problems": false,
    "created_at": "2026-09-11T14:42:00Z"
  }
  ```
- **Errors**:
  - `404 Not Found`: Questionnaire does not exist.

---

## 6. Risk Result Retrieval API

### `GET /api/screenings/{screening_id}/risk-result`
Retrieve risk assessment result for a completed screening session.

- **Path Parameters**:
  - `screening_id` (integer)
- **Response `200 OK`**:
  ```json
  {
    "id": 1,
    "screening_id": 101,
    "risk_score": 72.0,
    "risk_category": "Higher Risk",
    "contributing_factors": [
      "Smoking history",
      "Persistent breathlessness"
    ],
    "recommendation": "Clinical Evaluation Recommended",
    "created_at": "2026-09-11T14:45:00Z"
  }
  ```
- **Errors**:
  - `404 Not Found`: Risk assessment result does not exist for this screening.
