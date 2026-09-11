def test_create_patient(client):
    payload = {
        "full_name": "Rahul Patil",
        "age": 52,
        "gender": "Male",
        "village": "Satara",
        "occupation": "Farmer",
        "smoking_status": "former",
    }
    response = client.post("/api/patients", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert data["id"] is not None
    assert data["full_name"] == "Rahul Patil"
    assert data["age"] == 52
    assert data["gender"] == "Male"
    assert data["village"] == "Satara"
    assert data["occupation"] == "Farmer"
    assert data["smoking_status"] == "former"
    assert "created_at" in data
    assert "updated_at" in data


def test_get_patient_by_id(client):
    # Create patient first
    create_res = client.post(
        "/api/patients",
        json={"full_name": "Anita Sharma", "age": 46, "gender": "Female", "village": "Khed"},
    )
    patient_id = create_res.json()["id"]

    # Fetch patient
    response = client.get(f"/api/patients/{patient_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == patient_id
    assert data["full_name"] == "Anita Sharma"


def test_get_patient_not_found(client):
    response = client.get("/api/patients/99999")
    assert response.status_code == 404
    assert "not found" in response.json()["detail"].lower()


def test_get_all_patients(client):
    client.post(
        "/api/patients",
        json={"full_name": "Patient One", "age": 30, "gender": "Male"},
    )
    client.post(
        "/api/patients",
        json={"full_name": "Patient Two", "age": 40, "gender": "Female"},
    )

    response = client.get("/api/patients")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 2


def test_search_patients(client):
    client.post(
        "/api/patients",
        json={"full_name": "Gurunath Patil", "age": 35, "gender": "Male"},
    )

    response = client.get("/api/patients/search?q=Gurunath")
    assert response.status_code == 200
    data = response.json()
    assert len(data) >= 1
    assert any("Gurunath" in p["full_name"] for p in data)


def test_update_patient(client):
    create_res = client.post(
        "/api/patients",
        json={"full_name": "Vijay More", "age": 60, "gender": "Male", "village": "Wai"},
    )
    patient_id = create_res.json()["id"]

    update_payload = {"age": 61, "occupation": "Construction Worker"}
    response = client.put(f"/api/patients/{patient_id}", json=update_payload)
    assert response.status_code == 200
    data = response.json()
    assert data["age"] == 61
    assert data["occupation"] == "Construction Worker"
    assert data["full_name"] == "Vijay More"


def test_delete_patient(client):
    create_res = client.post(
        "/api/patients",
        json={"full_name": "Temporary Patient", "age": 25, "gender": "Other"},
    )
    patient_id = create_res.json()["id"]

    delete_res = client.delete(f"/api/patients/{patient_id}")
    assert delete_res.status_code == 204

    # Verify patient is gone
    get_res = client.get(f"/api/patients/{patient_id}")
    assert get_res.status_code == 404


def test_patient_validation_error(client):
    # Invalid age (negative)
    invalid_payload = {
        "full_name": "Bad Age",
        "age": -5,
        "gender": "Male",
    }
    response = client.post("/api/patients", json=invalid_payload)
    assert response.status_code == 422
