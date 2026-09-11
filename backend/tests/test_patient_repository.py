from app.repositories.patient_repository import patient_repository
from app.repositories.screening_repository import screening_repository
from app.schemas.patient import PatientCreate, PatientUpdate
from app.schemas.screening import ScreeningCreate


def test_patient_repository_create_and_get(db_session):
    patient_in = PatientCreate(
        full_name="Govind Shinde",
        age=54,
        gender="Male",
        village="Shirwal",
        occupation="Shopkeeper",
        smoking_status="former",
    )
    created = patient_repository.create(db_session, patient_in)
    assert created.id is not None
    assert created.full_name == "Govind Shinde"
    assert created.age == 54

    fetched = patient_repository.get_by_id(db_session, created.id)
    assert fetched is not None
    assert fetched.id == created.id
    assert fetched.village == "Shirwal"


def test_patient_repository_get_all_and_count(db_session):
    initial_count = patient_repository.count(db_session)

    p1 = patient_repository.create(
        db_session, PatientCreate(full_name="Patient Alpha", age=40, gender="Male")
    )
    p2 = patient_repository.create(
        db_session, PatientCreate(full_name="Patient Beta", age=45, gender="Female")
    )

    new_count = patient_repository.count(db_session)
    assert new_count == initial_count + 2

    all_patients = patient_repository.get_all(db_session, skip=0, limit=10)
    assert len(all_patients) >= 2


def test_patient_repository_search(db_session):
    patient_repository.create(
        db_session,
        PatientCreate(full_name="UniqueNameXYZ", age=60, gender="Male"),
    )

    results = patient_repository.search(db_session, "UniqueNameXYZ")
    assert len(results) == 1
    assert results[0].full_name == "UniqueNameXYZ"

    # Search empty / whitespace
    assert patient_repository.search(db_session, "") == []


def test_patient_repository_update(db_session):
    created = patient_repository.create(
        db_session,
        PatientCreate(full_name="Update Target", age=50, gender="Female", village="OldVillage"),
    )

    updated = patient_repository.update(
        db_session,
        created,
        PatientUpdate(village="NewVillage", occupation="Artisan"),
    )
    assert updated.village == "NewVillage"
    assert updated.occupation == "Artisan"
    assert updated.full_name == "Update Target"


def test_patient_repository_delete(db_session):
    created = patient_repository.create(
        db_session,
        PatientCreate(full_name="Delete Target", age=28, gender="Other"),
    )
    patient_id = created.id

    assert patient_repository.delete(db_session, patient_id) is True
    assert patient_repository.get_by_id(db_session, patient_id) is None
    # Deleting non-existent returns False
    assert patient_repository.delete(db_session, 99999) is False


def test_patient_repository_last_screening(db_session):
    patient = patient_repository.create(
        db_session,
        PatientCreate(full_name="Screening Recipient", age=55, gender="Male"),
    )

    # Initially no screening
    assert patient_repository.last_screening(db_session, patient.id) is None

    # Add screening
    s1 = screening_repository.create(db_session, ScreeningCreate(patient_id=patient.id))
    s2 = screening_repository.create(db_session, ScreeningCreate(patient_id=patient.id))

    last = patient_repository.last_screening(db_session, patient.id)
    assert last is not None
    assert last.id == s2.id
