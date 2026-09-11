def test_submit_and_get_and_update_questionnaire(client):
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

    # Submit (POST)
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

    # Get (GET)
    get_res = client.get(f"/api/screenings/{screening_id}/questionnaire")
    assert get_res.status_code == 200
    get_data = get_res.json()
    assert get_data["screening_id"] == screening_id
    assert get_data["smoking_status"] == "former"

    # Update (PUT)
    put_res = client.put(
        f"/api/screenings/{screening_id}/questionnaire",
        json={"years_smoked": 30, "cigarettes_per_day": 15},
    )
    assert put_res.status_code == 200
    put_data = put_res.json()
    assert put_data["years_smoked"] == 30
    assert put_data["cigarettes_per_day"] == 15
    assert put_data["biomass_exposure"] is True  # Preserves unchanged


def test_questionnaire_not_found(client):
    p_res = client.post(
        "/api/patients",
        json={"full_name": "No Questionnaire", "age": 40, "gender": "Female"},
    )
    patient_id = p_res.json()["id"]
    s_res = client.post("/api/screenings", json={"patient_id": patient_id})
    screening_id = s_res.json()["id"]

    # GET before creating returns 404
    get_res = client.get(f"/api/screenings/{screening_id}/questionnaire")
    assert get_res.status_code == 404

    # PUT before creating returns 404
    put_res = client.put(
        f"/api/screenings/{screening_id}/questionnaire",
        json={"years_smoked": 10},
    )
    assert put_res.status_code == 404
