import logging
from typing import Optional, List, Union
from sqlalchemy.orm import Session
from app.models.patient import Patient
from app.models.screening import ScreeningSession
from app.schemas.patient import PatientCreate, PatientUpdate

logger = logging.getLogger(__name__)


class PatientRepository:
    def create(self, db: Session, patient_in: PatientCreate) -> Patient:
        """Create and persist a new patient record."""
        db_patient = Patient(
            full_name=patient_in.full_name,
            age=patient_in.age,
            gender=patient_in.gender,
            village=patient_in.village,
            occupation=patient_in.occupation,
            smoking_status=patient_in.smoking_status,
        )
        db.add(db_patient)
        db.commit()
        db.refresh(db_patient)
        return db_patient

    def get_by_id(self, db: Session, patient_id: int) -> Optional[Patient]:
        """Retrieve a patient by their primary key."""
        return db.query(Patient).filter(Patient.id == patient_id).first()

    def get_all(self, db: Session, skip: int = 0, limit: int = 100) -> List[Patient]:
        """Retrieve paginated patient records ordered newest first."""
        return (
            db.query(Patient)
            .order_by(Patient.created_at.desc())
            .offset(skip)
            .limit(limit)
            .all()
        )

    def search(self, db: Session, query: str) -> List[Patient]:
        """Search patients by name matching pattern."""
        if not query or not query.strip():
            return []
        search_pattern = f"%{query.strip()}%"
        return db.query(Patient).filter(Patient.full_name.ilike(search_pattern)).all()

    def search_by_name(self, db: Session, query: str) -> List[Patient]:
        """Alias for search."""
        return self.search(db, query)

    def count(self, db: Session) -> int:
        """Count total registered patients."""
        return db.query(Patient).count()

    def update(
        self, db: Session, db_obj: Patient, obj_in: Union[PatientUpdate, dict]
    ) -> Patient:
        """Update an existing patient record."""
        if isinstance(obj_in, dict):
            update_data = obj_in
        else:
            update_data = obj_in.model_dump(exclude_unset=True)

        for field, value in update_data.items():
            if hasattr(db_obj, field):
                setattr(db_obj, field, value)

        db.add(db_obj)
        db.commit()
        db.refresh(db_obj)
        return db_obj

    def delete(self, db: Session, patient_id: int) -> bool:
        """Delete a patient record. Returns True if deleted, False if not found."""
        db_patient = self.get_by_id(db, patient_id)
        if not db_patient:
            return False
        db.delete(db_patient)
        db.commit()
        return True

    def last_screening(self, db: Session, patient_id: int) -> Optional[ScreeningSession]:
        """Get the most recent screening session for a patient."""
        return (
            db.query(ScreeningSession)
            .filter(ScreeningSession.patient_id == patient_id)
            .order_by(ScreeningSession.started_at.desc())
            .first()
        )


patient_repository = PatientRepository()
