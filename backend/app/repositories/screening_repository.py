from datetime import datetime, timezone
from typing import Optional, List, Union
from sqlalchemy.orm import Session, joinedload
from app.models.screening import ScreeningSession
from app.schemas.screening import ScreeningCreate, ScreeningUpdate


class ScreeningRepository:
    def create(self, db: Session, screening_in: ScreeningCreate) -> ScreeningSession:
        """Create and start a new screening session."""
        db_screening = ScreeningSession(
            patient_id=screening_in.patient_id,
            status="in_progress",
            started_at=datetime.now(timezone.utc),
        )
        db.add(db_screening)
        db.commit()
        db.refresh(db_screening)
        return db_screening

    def get_by_id(self, db: Session, screening_id: int) -> Optional[ScreeningSession]:
        """Retrieve a screening session by ID."""
        return db.query(ScreeningSession).filter(ScreeningSession.id == screening_id).first()

    def get_all(self, db: Session, skip: int = 0, limit: int = 100) -> List[ScreeningSession]:
        """Retrieve paginated screening sessions ordered newest first."""
        return (
            db.query(ScreeningSession)
            .order_by(ScreeningSession.started_at.desc())
            .offset(skip)
            .limit(limit)
            .all()
        )

    def get_by_patient(self, db: Session, patient_id: int) -> List[ScreeningSession]:
        """Retrieve all screening sessions for a patient ordered newest first."""
        return (
            db.query(ScreeningSession)
            .filter(ScreeningSession.patient_id == patient_id)
            .order_by(ScreeningSession.started_at.desc())
            .all()
        )

    def get_by_patient_id(self, db: Session, patient_id: int) -> List[ScreeningSession]:
        """Alias for get_by_patient."""
        return self.get_by_patient(db, patient_id)

    def update(
        self, db: Session, db_obj: ScreeningSession, obj_in: Union[ScreeningUpdate, dict]
    ) -> ScreeningSession:
        """Update screening session details."""
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

    def complete(self, db: Session, screening_id: int) -> Optional[ScreeningSession]:
        """Mark a screening session as completed."""
        db_screening = self.get_by_id(db, screening_id)
        if not db_screening:
            return None
        db_screening.status = "completed"
        db_screening.completed_at = datetime.now(timezone.utc)
        db.add(db_screening)
        db.commit()
        db.refresh(db_screening)
        return db_screening

    def count(self, db: Session) -> int:
        """Count total screening sessions recorded."""
        return db.query(ScreeningSession).count()

    def latest(self, db: Session, limit: int = 10) -> List[ScreeningSession]:
        """Retrieve most recent screening sessions."""
        return (
            db.query(ScreeningSession)
            .order_by(ScreeningSession.started_at.desc())
            .limit(limit)
            .all()
        )

    def get_complete_screening(
        self, db: Session, screening_id: int
    ) -> Optional[ScreeningSession]:
        """Retrieve screening session with all nested relationships eagerly loaded."""
        return (
            db.query(ScreeningSession)
            .options(
                joinedload(ScreeningSession.patient),
                joinedload(ScreeningSession.sensor_readings),
                joinedload(ScreeningSession.questionnaire_response),
                joinedload(ScreeningSession.risk_result),
            )
            .filter(ScreeningSession.id == screening_id)
            .first()
        )


screening_repository = ScreeningRepository()
