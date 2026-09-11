def test_submit_and_get_questionnaire(client):
    # Setup patient and screening
    p_res = client.post(
        "/api/patients",
        json={"full_name": "Questionnaire Patient", "age": 55, "gender": "Male"},
    )
    patient_id = p_res.json()["id"]
    s_res = client.post("/api/screenings", json={"patient_id": patient_id})
    screening_id = s_res.json()["id"]

    q_payload = {
        "smoking_status": "former",
        "years_smoked": 25,
        "cigarettes_per_day": 10,
        "biomass_exposure": True,
        "breathlessness": True,
        "chronic_cough": True,
        "phlegm": False,
        "wheezing": True,
        "recurrent_respiratory_problems": False,
    }

    # Submit
    response = client.post(
        f"/api/screenings/{screening_id}/questionnaire",
        json=q_payload,
    )
    assert response.status_code == 201
    data = response.json()
    assert data["screening_id"] == screening_id
    assert data["smoking_status"] == "former"
    assert data["years_smoked"] == 25
    assert data["biomass_exposure"] is True
    assert data["breathlessness"] is True
    assert data["chronic_cough"] is True
    assert data["phlegm"] is False

    # Get
    get_res = client.get(f"/api/screenings/{screening_id}/questionnaire")
    assert get_res.status_code == 200
    get_data = get_res.json()
    assert get_data["screening_id"] == screening_id
    assert get_data["smoking_status"] == "former"


def test_complete_end_to_end_screening_flow(client):
    """
    Test the complete end-to-end flow required by Section 23:
    1. Create patient
    2. Retrieve patient
    3. Start screening
    4. Add sensor reading
    5. Add questionnaire
    6. Retrieve complete screening
    """
    # 1. Create patient
    p_res = client.post(
        "/api/patients",
        json={
            "full_name": "E2E Test Subject",
            "age": 58,
            "gender": "Female",
            "village": "Rural Taluka",
            "occupation": "Agriculture",
            "smoking_status": "never",
        },
    )
    assert p_res.status_code == 201
    patient_id = p_res.json()["id"]

    # 2. Retrieve patient
    p_get = client.get(f"/api/patients/{patient_id}")
    assert p_get.status_code == 200
    assert p_get.json()["full_name"] == "E2E Test Subject"

    # 3. Start screening
    s_res = client.post("/api/screenings", json={"patient_id": patient_id})
    assert s_res.status_code == 201
    screening_id = s_res.json()["id"]

    # 4. Add sensor reading
    sensor_res = client.post(
        f"/api/screenings/{screening_id}/sensor-readings",
        json={"spo2": 95.5, "heart_rate": 84.0, "pressure": 2.1, "cough_activity": 0.45},
    )
    assert sensor_res.status_code == 201

    # 5. Add questionnaire
    q_res = client.post(
        f"/api/screenings/{screening_id}/questionnaire",
        json={
            "smoking_status": "never",
            "biomass_exposure": True,
            "breathlessness": True,
            "chronic_cough": False,
            "phlegm": False,
            "wheezing": False,
            "recurrent_respiratory_problems": True,
        },
    )
    assert q_res.status_code == 201

    # Complete the screening
    complete_res = client.put(f"/api/screenings/{screening_id}/complete")
    assert complete_res.status_code == 200

    # 6. Retrieve complete screening details
    detail_res = client.get(f"/api/screenings/{screening_id}")
    assert detail_res.status_code == 200
    detail_data = detail_res.json()
    assert detail_data["id"] == screening_id
    assert detail_data["status"] == "completed"
    assert detail_data["completed_at"] is not None
    assert len(detail_data["sensor_readings"]) == 1
    assert detail_data["sensor_readings"][0]["spo2"] == 95.5
    assert detail_data["questionnaire_response"] is not None
    assert detail_data["questionnaire_response"]["biomass_exposure"] is True
