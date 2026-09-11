from app.models.patient import Patient
from app.models.screening import ScreeningSession
from app.models.sensor_reading import SensorReading
from app.models.questionnaire import QuestionnaireResponse
from app.models.risk_result import RiskResult
from app.repositories.patient_repository import patient_repository
from app.repositories.screening_repository import screening_repository
from app.repositories.sensor_repository import sensor_repository
from app.repositories.questionnaire_repository import questionnaire_repository
from app.repositories.risk_repository import risk_result_repository
from app.schemas.patient import PatientCreate
from app.schemas.screening import ScreeningCreate
from app.schemas.sensor import SensorReadingCreate
from app.schemas.questionnaire import QuestionnaireCreate
from app.schemas.risk_result import RiskResultCreate


def test_model_relationships_and_cascades(db_session):
    # 1. Patient with multiple screenings
    patient = patient_repository.create(
        db_session,
        PatientCreate(full_name="Cascade Subject", age=63, gender="Female"),
    )
    s1 = screening_repository.create(db_session, ScreeningCreate(patient_id=patient.id))
    s2 = screening_repository.create(db_session, ScreeningCreate(patient_id=patient.id))

    # Verify Patient -> Screenings relationship
    refreshed_patient = patient_repository.get_by_id(db_session, patient.id)
    assert len(refreshed_patient.screenings) == 2
    assert refreshed_patient.screenings[0].patient.id == patient.id

    # 2. Screening with multiple sensor readings
    r1 = sensor_repository.create(
        db_session, s1.id, SensorReadingCreate(spo2=96.0, heart_rate=78.0)
    )
    r2 = sensor_repository.create(
        db_session, s1.id, SensorReadingCreate(spo2=97.0, heart_rate=76.0)
    )

    # 3. Screening with one questionnaire
    q = questionnaire_repository.create(
        db_session, s1.id, QuestionnaireCreate(smoking_status="former", biomass_exposure=True)
    )

    # 4. Screening with one risk result
    rr = risk_result_repository.create(
        db_session,
        s1.id,
        RiskResultCreate(
            screening_id=s1.id,
            risk_score=60.0,
            risk_category="Moderate Risk",
            contributing_factors=["Biomass exposure"],
        ),
    )

    # Verify relationships from Screening side
    full_s1 = screening_repository.get_complete_screening(db_session, s1.id)
    assert len(full_s1.sensor_readings) == 2
    assert full_s1.questionnaire_response.id == q.id
    assert full_s1.risk_result.id == rr.id

    # 5. Test Cascade Deletion: Deleting patient deletes screenings and all children
    patient_id = patient.id
    screening_id = s1.id
    sensor_id = r1.id
    q_id = q.id
    rr_id = rr.id

    patient_repository.delete(db_session, patient_id)

    assert db_session.query(Patient).filter(Patient.id == patient_id).first() is None
    assert db_session.query(ScreeningSession).filter(ScreeningSession.id == screening_id).first() is None
    assert db_session.query(SensorReading).filter(SensorReading.id == sensor_id).first() is None
    assert db_session.query(QuestionnaireResponse).filter(QuestionnaireResponse.id == q_id).first() is None
    assert db_session.query(RiskResult).filter(RiskResult.id == rr_id).first() is None
