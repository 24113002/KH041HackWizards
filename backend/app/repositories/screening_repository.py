from datetime import datetime, timezone
from typing import Optional, List
from sqlalchemy.orm import Session
from app.models.screening import ScreeningSession
from app.schemas.screening import ScreeningCreate, ScreeningUpdate


class ScreeningRepository:
    def create(self, db: Session, screening_in: ScreeningCreate) -> ScreeningSession:
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
        return db.query(ScreeningSession).filter(ScreeningSession.id == screening_id).first()

    def get_all(self, db: Session, skip: int = 0, limit: int = 100) -> List[ScreeningSession]:
        return (
            db.query(ScreeningSession)
            .order_by(ScreeningSession.started_at.desc())
            .offset(skip)
            .limit(limit)
            .all()
        )

    def get_by_patient_id(self, db: Session, patient_id: int) -> List[ScreeningSession]:
        return (
            db.query(ScreeningSession)
            .filter(ScreeningSession.patient_id == patient_id)
            .order_by(ScreeningSession.started_at.desc())
            .all()
        )

    def update(
        self, db: Session, db_obj: ScreeningSession, obj_in: ScreeningUpdate
    ) -> ScreeningSession:
        update_data = obj_in.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_obj, field, value)
        db.add(db_obj)
        db.commit()
        db.refresh(db_obj)
        return db_obj

    def complete(self, db: Session, screening_id: int) -> Optional[ScreeningSession]:
        db_screening = self.get_by_id(db, screening_id)
        if not db_screening:
            return None
        db_screening.status = "completed"
        db_screening.completed_at = datetime.now(timezone.utc)
        db.add(db_screening)
        db.commit()
        db.refresh(db_screening)
        return db_screening


screening_repository = ScreeningRepository()
