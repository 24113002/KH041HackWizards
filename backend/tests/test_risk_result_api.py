from app.repositories.risk_repository import risk_result_repository
from app.schemas.risk_result import RiskResultCreate


def test_get_risk_result_api_and_not_found(client, db_session):
    p_res = client.post(
        "/api/patients",
        json={"full_name": "Risk API Patient", "age": 62, "gender": "Male"},
    )
    patient_id = p_res.json()["id"]
    s_res = client.post("/api/screenings", json={"patient_id": patient_id})
    screening_id = s_res.json()["id"]

    # 1. Before risk assessment exists -> 404 Not Found
    res404 = client.get(f"/api/screenings/{screening_id}/risk-result")
    assert res404.status_code == 404

    # 2. Add risk result record in database
    risk_result_repository.create(
        db_session,
        screening_id,
        RiskResultCreate(
            screening_id=screening_id,
            risk_score=72.0,
            risk_category="Higher Risk",
            contributing_factors=["Smoking history", "Persistent breathlessness"],
            recommendation="Clinical Evaluation Recommended",
        ),
    )

    # 3. Retrieve risk result via API -> 200 OK
    res200 = client.get(f"/api/screenings/{screening_id}/risk-result")
    assert res200.status_code == 200
    data = res200.json()
    assert data["screening_id"] == screening_id
    assert data["risk_score"] == 72.0
    assert data["risk_category"] == "Higher Risk"
    assert "Smoking history" in data["contributing_factors"]
