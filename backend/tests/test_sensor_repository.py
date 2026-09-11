from app.repositories.patient_repository import patient_repository
from app.repositories.screening_repository import screening_repository
from app.repositories.sensor_repository import sensor_repository
from app.schemas.patient import PatientCreate
from app.schemas.screening import ScreeningCreate
from app.schemas.sensor import SensorReadingCreate


def test_sensor_repository_single_and_batch_and_latest(db_session):
    patient = patient_repository.create(
        db_session, PatientCreate(full_name="Sensor Repo Patient", age=45, gender="Female")
    )
    screening = screening_repository.create(db_session, ScreeningCreate(patient_id=patient.id))

    # Single creation
    r1 = sensor_repository.create(
        db_session,
        screening.id,
        SensorReadingCreate(spo2=98.0, heart_rate=72.0, pressure=1.2, cough_activity=0.1),
    )
    assert r1.id is not None
    assert r1.spo2 == 98.0

    # Batch creation (create_many)
    batch = [
        SensorReadingCreate(spo2=97.0, heart_rate=75.0, pressure=1.4, cough_activity=0.2),
        SensorReadingCreate(spo2=95.0, heart_rate=82.0, pressure=1.8, cough_activity=0.5),
    ]
    created_batch = sensor_repository.create_many(db_session, screening.id, batch)
    assert len(created_batch) == 2

    # Get all for screening
    all_readings = sensor_repository.get_by_screening(db_session, screening.id)
    assert len(all_readings) == 3

    # Get latest reading
    latest = sensor_repository.get_latest(db_session, screening.id)
    assert latest is not None
    assert latest.id == created_batch[1].id
