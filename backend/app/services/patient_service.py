import logging
from typing import List
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from app.models.patient import Patient
from app.schemas.patient import PatientCreate, PatientUpdate
from app.repositories.patient_repository import patient_repository

logger = logging.getLogger(__name__)


class PatientService:
    def create_patient(self, db: Session, patient_in: PatientCreate) -> Patient:
        logger.info("Creating new patient record: %s", patient_in.full_name)
        return patient_repository.create(db, patient_in)

    def get_patient(self, db: Session, patient_id: int) -> Patient:
        patient = patient_repository.get_by_id(db, patient_id)
        if not patient:
            logger.warning("Patient not found with ID: %d", patient_id)
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Patient with ID {patient_id} not found",
            )
        return patient

    def get_all_patients(
        self, db: Session, skip: int = 0, limit: int = 100
    ) -> List[Patient]:
        return patient_repository.get_all(db, skip=skip, limit=limit)

    def search_patients(self, db: Session, query: str) -> List[Patient]:
        if not query or not query.strip():
            return []
        return patient_repository.search_by_name(db, query.strip())

    def update_patient(
        self, db: Session, patient_id: int, patient_in: PatientUpdate
    ) -> Patient:
        patient = self.get_patient(db, patient_id)
        logger.info("Updating patient ID: %d", patient_id)
        return patient_repository.update(db, patient, patient_in)

    def delete_patient(self, db: Session, patient_id: int) -> None:
        patient = self.get_patient(db, patient_id)
        logger.info("Deleting patient ID: %d", patient_id)
        patient_repository.delete(db, patient.id)


patient_service = PatientService()
