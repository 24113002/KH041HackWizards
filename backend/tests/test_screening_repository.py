from app.repositories.patient_repository import patient_repository
from app.repositories.screening_repository import screening_repository
from app.repositories.sensor_repository import sensor_repository
from app.repositories.questionnaire_repository import questionnaire_repository
from app.repositories.risk_repository import risk_result_repository
from app.schemas.patient import PatientCreate
from app.schemas.screening import ScreeningCreate, ScreeningUpdate
from app.schemas.sensor import SensorReadingCreate
from app.schemas.questionnaire import QuestionnaireCreate
from app.schemas.risk_result import RiskResultCreate


def test_screening_repository_crud(db_session):
    patient = patient_repository.create(
        db_session, PatientCreate(full_name="Screening Patient", age=48, gender="Female")
    )

    screening = screening_repository.create(db_session, ScreeningCreate(patient_id=patient.id))
    assert screening.id is not None
    assert screening.patient_id == patient.id
    assert screening.status == "in_progress"

    # Get by ID
    fetched = screening_repository.get_by_id(db_session, screening.id)
    assert fetched is not None
    assert fetched.id == screening.id

    # Update
    updated = screening_repository.update(
        db_session, fetched, ScreeningUpdate(risk_score=42.5, risk_category="Moderate Risk")
    )
    assert updated.risk_score == 42.5
    assert updated.risk_category == "Moderate Risk"

    # Complete
    completed = screening_repository.complete(db_session, screening.id)
    assert completed.status == "completed"
    assert completed.completed_at is not None

    # Complete non-existent returns None
    assert screening_repository.complete(db_session, 99999) is None


def test_screening_repository_queries_and_counts(db_session):
    patient = patient_repository.create(
        db_session, PatientCreate(full_name="Multi-Screen Patient", age=62, gender="Male")
    )

    s1 = screening_repository.create(db_session, ScreeningCreate(patient_id=patient.id))
    s2 = screening_repository.create(db_session, ScreeningCreate(patient_id=patient.id))

    by_patient = screening_repository.get_by_patient(db_session, patient.id)
    assert len(by_patient) == 2

    assert screening_repository.count(db_session) >= 2
    latest = screening_repository.latest(db_session, limit=2)
    assert len(latest) == 2


def test_screening_repository_get_complete_screening(db_session):
    patient = patient_repository.create(
        db_session, PatientCreate(full_name="Full Screening Target", age=57, gender="Male")
    )
    screening = screening_repository.create(db_session, ScreeningCreate(patient_id=patient.id))

    # Add sensor reading
    sensor_repository.create(
        db_session,
        screening.id,
        SensorReadingCreate(spo2=96.0, heart_rate=80.0, pressure=1.5, cough_activity=0.3),
    )

    # Add questionnaire
    questionnaire_repository.create(
        db_session,
        screening.id,
        QuestionnaireCreate(smoking_status="current", biomass_exposure=True, chronic_cough=True),
    )

    # Add risk result
    risk_result_repository.create(
        db_session,
        screening.id,
        RiskResultCreate(
            screening_id=screening.id,
            risk_score=75.0,
            risk_category="Higher Risk",
            contributing_factors=["Smoking history", "Biomass fuel exposure"],
            recommendation="Clinical Evaluation Recommended",
        ),
    )

    # Fetch complete screening
    full = screening_repository.get_complete_screening(db_session, screening.id)
    assert full is not None
    assert full.patient.full_name == "Full Screening Target"
    assert len(full.sensor_readings) == 1
    assert full.sensor_readings[0].spo2 == 96.0
    assert full.questionnaire_response is not None
    assert full.questionnaire_response.biomass_exposure is True
    assert full.risk_result is not None
    assert full.risk_result.risk_score == 75.0
    assert "Smoking history" in full.risk_result.contributing_factors
