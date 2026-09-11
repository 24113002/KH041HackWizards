def test_start_screening(client):
    # Create patient
    p_res = client.post(
        "/api/patients",
        json={"full_name": "Test Patient", "age": 50, "gender": "Male"},
    )
    patient_id = p_res.json()["id"]

    # Start screening
    response = client.post("/api/screenings", json={"patient_id": patient_id})
    assert response.status_code == 201
    data = response.json()
    assert data["id"] is not None
    assert data["patient_id"] == patient_id
    assert data["status"] == "in_progress"
    assert data["started_at"] is not None
    assert data["completed_at"] is None
    assert data["risk_score"] is None
    assert data["risk_category"] is None


def test_start_screening_invalid_patient(client):
    response = client.post("/api/screenings", json={"patient_id": 99999})
    assert response.status_code == 404


def test_get_screenings(client):
    p_res = client.post(
        "/api/patients",
        json={"full_name": "List Test Patient", "age": 45, "gender": "Female"},
    )
    patient_id = p_res.json()["id"]
    client.post("/api/screenings", json={"patient_id": patient_id})

    response = client.get("/api/screenings")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 1


def test_get_patient_screenings(client):
    p_res = client.post(
        "/api/patients",
        json={"full_name": "History Patient", "age": 55, "gender": "Male"},
    )
    patient_id = p_res.json()["id"]
    client.post("/api/screenings", json={"patient_id": patient_id})
    client.post("/api/screenings", json={"patient_id": patient_id})

    response = client.get(f"/api/patients/{patient_id}/screenings")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2


def test_complete_screening_post_and_put(client):
    p_res = client.post(
        "/api/patients",
        json={"full_name": "Complete Test", "age": 60, "gender": "Male"},
    )
    patient_id = p_res.json()["id"]

    # Test POST /complete
    s_res = client.post("/api/screenings", json={"patient_id": patient_id})
    screening_id = s_res.json()["id"]

    response_post = client.post(f"/api/screenings/{screening_id}/complete")
    assert response_post.status_code == 200
    data_post = response_post.json()
    assert data_post["status"] == "completed"
    assert data_post["completed_at"] is not None

    # Test PUT /complete on another screening
    s_res2 = client.post("/api/screenings", json={"patient_id": patient_id})
    screening_id2 = s_res2.json()["id"]

    response_put = client.put(f"/api/screenings/{screening_id2}/complete")
    assert response_put.status_code == 200
    data_put = response_put.json()
    assert data_put["status"] == "completed"
    assert data_put["completed_at"] is not None
