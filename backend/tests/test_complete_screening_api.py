def test_complete_end_to_end_b3_screening_flow(client):
    """
    Test complete end-to-end API flow for Phase B3:
    1. Create Patient
    2. Start Screening
    3. Add Sensor Reading
    4. Add Multiple Sensor Readings (Bulk)
    5. Add Questionnaire
    6. Retrieve Screening
    7. Retrieve Patient Screening History
    8. Complete Screening
    9. Retrieve Complete Screening Aggregation
    """
    # 1. Create Patient
    p_res = client.post(
        "/api/patients",
        json={
            "full_name": "Ramesh Kulkarni",
            "age": 59,
            "gender": "Male",
            "village": "Karad",
            "occupation": "Farmer",
            "smoking_status": "former",
        },
    )
    assert p_res.status_code == 201
    patient_id = p_res.json()["id"]

    # 2. Start Screening
    s_res = client.post("/api/screenings", json={"patient_id": patient_id})
    assert s_res.status_code == 201
    screening_id = s_res.json()["id"]
    assert s_res.json()["status"] == "in_progress"

    # 3. Add Single Sensor Reading
    r1_res = client.post(
        f"/api/screenings/{screening_id}/sensor-data",
        json={"spo2": 96.0, "heart_rate": 78.0, "pressure": 1.45, "cough_activity": 0.12},
    )
    assert r1_res.status_code == 201

    # 4. Add Multiple Sensor Readings in Bulk
    bulk_res = client.post(
        f"/api/screenings/{screening_id}/sensor-data/bulk",
        json={
            "readings": [
                {"spo2": 95.8, "heart_rate": 80.0, "pressure": 1.50, "cough_activity": 0.20},
                {"spo2": 95.0, "heart_rate": 82.0, "pressure": 1.62, "cough_activity": 0.35},
            ]
        },
    )
    assert bulk_res.status_code == 201
    assert len(bulk_res.json()) == 2

    # 5. Add Questionnaire
    q_res = client.post(
        f"/api/screenings/{screening_id}/questionnaire",
        json={
            "smoking_status": "former",
            "years_smoked": 20,
            "cigarettes_per_day": 8,
            "biomass_exposure": True,
            "breathlessness": True,
            "chronic_cough": True,
            "phlegm": False,
            "wheezing": True,
            "recurrent_respiratory_problems": False,
        },
    )
    assert q_res.status_code == 201

    # 6. Retrieve Screening
    detail_res = client.get(f"/api/screenings/{screening_id}")
    assert detail_res.status_code == 200
    detail_data = detail_res.json()
    assert detail_data["id"] == screening_id
    assert len(detail_data["sensor_readings"]) == 3
    assert detail_data["questionnaire_response"] is not None

    # 7. Retrieve Patient Screening History
    history_res = client.get(f"/api/patients/{patient_id}/screenings")
    assert history_res.status_code == 200
    history_data = history_res.json()
    assert len(history_data) >= 1
    assert history_data[0]["id"] == screening_id

    # 8. Complete Screening
    comp_res = client.post(f"/api/screenings/{screening_id}/complete")
    assert comp_res.status_code == 200
    assert comp_res.json()["status"] == "completed"
    assert comp_res.json()["completed_at"] is not None

    # 9. Retrieve Complete Screening Aggregation Endpoint
    complete_agg_res = client.get(f"/api/screenings/{screening_id}/complete")
    assert complete_agg_res.status_code == 200
    agg_data = complete_agg_res.json()
    assert agg_data["patient"]["full_name"] == "Ramesh Kulkarni"
    assert agg_data["screening"]["status"] == "completed"
    assert len(agg_data["sensor_readings"]) == 3
    assert agg_data["questionnaire"]["biomass_exposure"] is True
    assert agg_data["questionnaire"]["smoking_status"] == "former"
