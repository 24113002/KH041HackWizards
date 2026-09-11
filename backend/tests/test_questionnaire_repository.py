from app.repositories.patient_repository import patient_repository
from app.repositories.screening_repository import screening_repository
from app.repositories.questionnaire_repository import questionnaire_repository
from app.schemas.patient import PatientCreate
from app.schemas.screening import ScreeningCreate
from app.schemas.questionnaire import QuestionnaireCreate


def test_questionnaire_repository_create_update_and_duplicate_handling(db_session):
    patient = patient_repository.create(
        db_session, PatientCreate(full_name="Questionnaire Tester", age=53, gender="Male")
    )
    screening = screening_repository.create(db_session, ScreeningCreate(patient_id=patient.id))

    # Initial creation
    q_in = QuestionnaireCreate(
        smoking_status="former",
        years_smoked=15,
        cigarettes_per_day=5,
        biomass_exposure=False,
        breathlessness=True,
    )
    created = questionnaire_repository.create(db_session, screening.id, q_in)
    assert created.id is not None
    assert created.smoking_status == "former"
    assert created.years_smoked == 15
    assert created.breathlessness is True

    # Retrieve
    fetched = questionnaire_repository.get_by_screening(db_session, screening.id)
    assert fetched is not None
    assert fetched.id == created.id

    # Create again on same screening should update existing (prevent duplicates)
    q_update = QuestionnaireCreate(
        smoking_status="current",
        years_smoked=20,
        cigarettes_per_day=10,
        biomass_exposure=True,
        breathlessness=True,
    )
    updated = questionnaire_repository.create(db_session, screening.id, q_update)
    assert updated.id == created.id  # Same record updated
    assert updated.smoking_status == "current"
    assert updated.years_smoked == 20
    assert updated.biomass_exposure is True

    # Direct update method
    questionnaire_repository.update(db_session, screening.id, {"chronic_cough": True})
    refetched = questionnaire_repository.get_by_screening(db_session, screening.id)
    assert refetched.chronic_cough is True
