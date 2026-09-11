from app.repositories.patient_repository import patient_repository
from app.repositories.screening_repository import screening_repository
from app.repositories.risk_repository import risk_result_repository
from app.schemas.patient import PatientCreate
from app.schemas.screening import ScreeningCreate
from app.schemas.risk_result import RiskResultCreate


def test_risk_result_repository_crud_and_upsert(db_session):
    patient = patient_repository.create(
        db_session, PatientCreate(full_name="Risk Test Patient", age=65, gender="Male")
    )
    screening = screening_repository.create(db_session, ScreeningCreate(patient_id=patient.id))

    # Initial creation
    res_in = RiskResultCreate(
        screening_id=screening.id,
        risk_score=35.0,
        risk_category="Moderate Risk",
        contributing_factors=["Age over 60", "Occasional breathlessness"],
        recommendation="Follow up in 3 months",
    )
    created = risk_result_repository.create(db_session, screening.id, res_in)
    assert created.id is not None
    assert created.risk_score == 35.0
    assert created.risk_category == "Moderate Risk"
    assert len(created.contributing_factors) == 2

    # Get by screening
    fetched = risk_result_repository.get_by_screening(db_session, screening.id)
    assert fetched is not None
    assert fetched.id == created.id

    # Create again updates existing record (single risk result per screening)
    res_update = RiskResultCreate(
        screening_id=screening.id,
        risk_score=68.0,
        risk_category="Higher Risk",
        contributing_factors=["Age over 60", "Breathlessness", "Smoking"],
        recommendation="Clinical Evaluation Recommended",
    )
    updated = risk_result_repository.create(db_session, screening.id, res_update)
    assert updated.id == created.id
    assert updated.risk_score == 68.0
    assert updated.risk_category == "Higher Risk"
