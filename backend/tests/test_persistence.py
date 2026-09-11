import tempfile
from pathlib import Path
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.core.database import Base
from app.models.patient import Patient
from app.models.screening import ScreeningSession
from app.repositories.patient_repository import patient_repository
from app.repositories.screening_repository import screening_repository
from app.schemas.patient import PatientCreate
from app.schemas.screening import ScreeningCreate


def test_sqlite_session_persistence():
    """Verify data is persisted to SQLite file across completely independent sessions."""
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_db_path = Path(temp_dir) / "test_persistence.db"
        temp_db_url = f"sqlite:///{temp_db_path.as_posix()}"

        engine = create_engine(temp_db_url, connect_args={"check_same_thread": False})
        Base.metadata.create_all(bind=engine)
        SessionMaker = sessionmaker(autocommit=False, autoflush=False, bind=engine)

        # Session 1: Create Patient and Screening
        session1 = SessionMaker()
        patient = patient_repository.create(
            session1,
            PatientCreate(
                full_name="Persistent Patient",
                age=51,
                gender="Male",
                village="Test Village",
                occupation="Farmer",
                smoking_status="former",
            ),
        )
        patient_id = patient.id
        screening = screening_repository.create(
            session1, ScreeningCreate(patient_id=patient_id)
        )
        screening_id = screening.id
        session1.close()  # Session 1 closed and terminated

        # Session 2: Fresh independent session to verify offline data persistence
        session2 = SessionMaker()
        fetched_patient = patient_repository.get_by_id(session2, patient_id)
        assert fetched_patient is not None
        assert fetched_patient.full_name == "Persistent Patient"
        assert fetched_patient.age == 51

        fetched_screening = screening_repository.get_by_id(session2, screening_id)
        assert fetched_screening is not None
        assert fetched_screening.patient_id == patient_id
        assert fetched_screening.status == "in_progress"

        session2.close()
        engine.dispose()
