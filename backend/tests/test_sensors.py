def test_add_sensor_reading(client):
    # Setup patient and screening
    p_res = client.post(
        "/api/patients",
        json={"full_name": "Sensor Patient", "age": 48, "gender": "Female"},
    )
    patient_id = p_res.json()["id"]
    s_res = client.post("/api/screenings", json={"patient_id": patient_id})
    screening_id = s_res.json()["id"]

    reading_payload = {
        "spo2": 97.0,
        "heart_rate": 82.0,
        "pressure": 1.84,
        "cough_activity": 0.72,
    }
    response = client.post(
        f"/api/screenings/{screening_id}/sensor-readings",
        json=reading_payload,
    )
    assert response.status_code == 201
    data = response.json()
    assert data["id"] is not None
    assert data["screening_id"] == screening_id
    assert data["spo2"] == 97.0
    assert data["heart_rate"] == 82.0
    assert data["pressure"] == 1.84
    assert data["cough_activity"] == 0.72
    assert "timestamp" in data


def test_get_sensor_readings(client):
    p_res = client.post(
        "/api/patients",
        json={"full_name": "Sensor Read Patient", "age": 50, "gender": "Male"},
    )
    patient_id = p_res.json()["id"]
    s_res = client.post("/api/screenings", json={"patient_id": patient_id})
    screening_id = s_res.json()["id"]

    # Add two readings
    client.post(
        f"/api/screenings/{screening_id}/sensor-readings",
        json={"spo2": 98.0, "heart_rate": 75.0},
    )
    client.post(
        f"/api/screenings/{screening_id}/sensor-readings",
        json={"spo2": 96.0, "heart_rate": 78.0},
    )

    response = client.get(f"/api/screenings/{screening_id}/sensor-readings")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2


def test_add_sensor_reading_nonexistent_screening(client):
    response = client.post(
        "/api/screenings/99999/sensor-readings",
        json={"spo2": 98.0, "heart_rate": 75.0},
    )
    assert response.status_code == 404
