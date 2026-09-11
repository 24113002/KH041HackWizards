from typing import Optional, List
from sqlalchemy.orm import Session
from app.models.patient import Patient
from app.schemas.patient import PatientCreate, PatientUpdate


class PatientRepository:
    def create(self, db: Session, patient_in: PatientCreate) -> Patient:
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
        return db.query(Patient).filter(Patient.id == patient_id).first()

    def get_all(self, db: Session, skip: int = 0, limit: int = 100) -> List[Patient]:
        return db.query(Patient).order_by(Patient.created_at.desc()).offset(skip).limit(limit).all()

    def search_by_name(self, db: Session, query: str) -> List[Patient]:
        search_pattern = f"%{query}%"
        return db.query(Patient).filter(Patient.full_name.ilike(search_pattern)).all()

    def update(self, db: Session, db_obj: Patient, obj_in: PatientUpdate) -> Patient:
        update_data = obj_in.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_obj, field, value)
        db.add(db_obj)
        db.commit()
        db.refresh(db_obj)
        return db_obj

    def delete(self, db: Session, patient_id: int) -> bool:
        db_patient = self.get_by_id(db, patient_id)
        if not db_patient:
            return False
        db.delete(db_patient)
        db.commit()
        return True


patient_repository = PatientRepository()
