# SwasthAI Backend API Contract (v0.1.0 - Phase B1)

> **IMPORTANT MEDICAL NOTICE**:  
> SwasthAI is an offline screening-support system designed for rural frontline healthcare workers. It is **NOT** a diagnostic medical device and does **NOT** provide a definitive medical diagnosis of COPD.

---

## Base URL
- Local Development Default: `http://127.0.0.1:8000`
- API Prefix: `/api`

---

## 1. System & Health

### `GET /health`
Verify that the local offline backend is operational.

- **Request Body**: None
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
    "smoking_status": "former"
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
    "smoking_status": "former",
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
      "smoking_status": "former",
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
      "smoking_status": "former",
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
    "smoking_status": "former",
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
    "smoking_status": "former",
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
List all screening sessions conducted for a specific patient.

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
Retrieve complete screening session details including sensor readings, questionnaire responses, and risk result.

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
    "sensor_readings": [
      {
        "id": 1,
        "screening_id": 101,
        "timestamp": "2026-09-11T14:41:00Z",
        "spo2": 97.0,
        "heart_rate": 82.0,
        "pressure": 1.84,
        "cough_activity": 0.72
      }
    ],
    "questionnaire_response": {
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
    },
    "risk_result": null
  }
  ```
- **Errors**:
  - `404 Not Found`: Screening session not found.

---

### `PUT /api/screenings/{screening_id}/complete`
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

## 4. Sensor Readings

### `POST /api/screenings/{screening_id}/sensor-readings`
Store an instantaneous or summarized sensor reading (SpO2, Heart Rate, Pressure, Acoustic Cough Activity).

- **Path Parameters**:
  - `screening_id` (integer)
- **Request Body (`application/json`)**:
  ```json
  {
    "spo2": 97.0,
    "heart_rate": 82.0,
    "pressure": 1.84,
    "cough_activity": 0.72
  }
  ```
- **Response `201 Created`**:
  ```json
  {
    "id": 1,
    "screening_id": 101,
    "timestamp": "2026-09-11T14:41:00Z",
    "spo2": 97.0,
    "heart_rate": 82.0,
    "pressure": 1.84,
    "cough_activity": 0.72
  }
  ```
- **Errors**:
  - `404 Not Found`: Screening session not found.
  - `422 Unprocessable Content`: Validation failure.

---

### `GET /api/screenings/{screening_id}/sensor-readings`
Get all recorded sensor readings for a screening session.

- **Path Parameters**:
  - `screening_id` (integer)
- **Response `200 OK`**:
  ```json
  [
    {
      "id": 1,
      "screening_id": 101,
      "timestamp": "2026-09-11T14:41:00Z",
      "spo2": 97.0,
      "heart_rate": 82.0,
      "pressure": 1.84,
      "cough_activity": 0.72
    }
  ]
  ```
- **Errors**:
  - `404 Not Found`: Screening session not found.

---

## 5. Questionnaire Responses

### `POST /api/screenings/{screening_id}/questionnaire`
Submit or update clinical risk questionnaire responses for a screening session.

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
- **Errors**:
  - `404 Not Found`: Screening session not found.
  - `422 Unprocessable Content`: Validation failure.

---

### `GET /api/screenings/{screening_id}/questionnaire`
Retrieve the questionnaire responses for a screening session.

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
  - `404 Not Found`: Screening session or questionnaire not found.
