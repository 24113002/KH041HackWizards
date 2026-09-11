import logging
from typing import List, Optional
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from app.models.screening import ScreeningSession
from app.models.sensor_reading import SensorReading
from app.models.questionnaire import QuestionnaireResponse
from app.models.risk_result import RiskResult
from app.schemas.screening import ScreeningCreate, ScreeningUpdate
from app.schemas.sensor import SensorReadingCreate
from app.schemas.questionnaire import QuestionnaireCreate
from app.schemas.risk_result import RiskResultCreate
from app.repositories.screening_repository import screening_repository
from app.repositories.patient_repository import patient_repository
from app.repositories.sensor_repository import sensor_repository
from app.repositories.questionnaire_repository import questionnaire_repository
from app.repositories.risk_repository import risk_result_repository

logger = logging.getLogger(__name__)


class ScreeningService:
    def start_screening(
        self, db: Session, screening_in: ScreeningCreate
    ) -> ScreeningSession:
        patient = patient_repository.get_by_id(db, screening_in.patient_id)
        if not patient:
            logger.warning(
                "Cannot start screening: Patient ID %d not found",
                screening_in.patient_id,
            )
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Patient with ID {screening_in.patient_id} not found",
            )
        logger.info(
            "Starting new screening session for patient ID: %d",
            screening_in.patient_id,
        )
        return screening_repository.create(db, screening_in)

    def get_screening(self, db: Session, screening_id: int) -> ScreeningSession:
        screening = screening_repository.get_by_id(db, screening_id)
        if not screening:
            logger.warning("Screening session not found with ID: %d", screening_id)
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Screening session with ID {screening_id} not found",
            )
        return screening

    def get_complete_screening(
        self, db: Session, screening_id: int
    ) -> ScreeningSession:
        screening = screening_repository.get_complete_screening(db, screening_id)
        if not screening:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Screening session with ID {screening_id} not found",
            )
        return screening

    def get_all_screenings(
        self, db: Session, skip: int = 0, limit: int = 100
    ) -> List[ScreeningSession]:
        return screening_repository.get_all(db, skip=skip, limit=limit)

    def get_patient_screenings(
        self, db: Session, patient_id: int
    ) -> List[ScreeningSession]:
        patient = patient_repository.get_by_id(db, patient_id)
        if not patient:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Patient with ID {patient_id} not found",
            )
        return screening_repository.get_by_patient_id(db, patient_id)

    def complete_screening(
        self, db: Session, screening_id: int
    ) -> ScreeningSession:
        screening = self.get_screening(db, screening_id)
        updated = screening_repository.complete(db, screening.id)
        logger.info("Screening session ID %d marked as completed", screening_id)
        return updated

    def add_sensor_reading(
        self, db: Session, screening_id: int, reading_in: SensorReadingCreate
    ) -> SensorReading:
        self.get_screening(db, screening_id)
        logger.info("Adding sensor reading for screening ID: %d", screening_id)
        return sensor_repository.create(db, screening_id, reading_in)

    def add_multiple_sensor_readings(
        self, db: Session, screening_id: int, readings_in: List[SensorReadingCreate]
    ) -> List[SensorReading]:
        self.get_screening(db, screening_id)
        logger.info("Adding %d sensor readings for screening ID: %d", len(readings_in), screening_id)
        return sensor_repository.create_many(db, screening_id, readings_in)

    def get_sensor_readings(
        self, db: Session, screening_id: int
    ) -> List[SensorReading]:
        self.get_screening(db, screening_id)
        return sensor_repository.get_by_screening_id(db, screening_id)

    def get_latest_sensor_reading(
        self, db: Session, screening_id: int
    ) -> Optional[SensorReading]:
        self.get_screening(db, screening_id)
        return sensor_repository.get_latest(db, screening_id)

    def submit_questionnaire(
        self, db: Session, screening_id: int, questionnaire_in: QuestionnaireCreate
    ) -> QuestionnaireResponse:
        self.get_screening(db, screening_id)
        logger.info("Submitting questionnaire for screening ID: %d", screening_id)
        return questionnaire_repository.create_or_update(
            db, screening_id, questionnaire_in
        )

    def get_questionnaire(
        self, db: Session, screening_id: int
    ) -> QuestionnaireResponse:
        self.get_screening(db, screening_id)
        questionnaire = questionnaire_repository.get_by_screening_id(db, screening_id)
        if not questionnaire:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Questionnaire response not found for screening ID {screening_id}",
            )
        return questionnaire

    def save_risk_result(
        self, db: Session, screening_id: int, result_in: RiskResultCreate
    ) -> RiskResult:
        self.get_screening(db, screening_id)
        logger.info("Saving risk screening result for screening ID: %d", screening_id)
        return risk_result_repository.create_or_update(db, screening_id, result_in)

    def get_risk_result(
        self, db: Session, screening_id: int
    ) -> Optional[RiskResult]:
        self.get_screening(db, screening_id)
        return risk_result_repository.get_by_screening(db, screening_id)


screening_service = ScreeningService()
