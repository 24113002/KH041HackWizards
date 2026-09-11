from typing import List, Optional
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.models.sensor_reading import SensorReading
from app.schemas.sensor import SensorReadingCreate


class SensorReadingRepository:
    def create(
        self, db: Session, screening_id: int, reading_in: SensorReadingCreate
    ) -> SensorReading:
        """Create and persist a single sensor reading."""
        db_reading = SensorReading(
            screening_id=screening_id,
            timestamp=datetime.now(timezone.utc),
            spo2=reading_in.spo2,
            heart_rate=reading_in.heart_rate,
            pressure=reading_in.pressure,
            cough_activity=reading_in.cough_activity,
        )
        db.add(db_reading)
        db.commit()
        db.refresh(db_reading)
        return db_reading

    def create_many(
        self, db: Session, screening_id: int, readings_in: List[SensorReadingCreate]
    ) -> List[SensorReading]:
        """Batch insert multiple continuous sensor readings."""
        created_objects = []
        for r in readings_in:
            db_reading = SensorReading(
                screening_id=screening_id,
                timestamp=datetime.now(timezone.utc),
                spo2=r.spo2,
                heart_rate=r.heart_rate,
                pressure=r.pressure,
                cough_activity=r.cough_activity,
            )
            db.add(db_reading)
            created_objects.append(db_reading)

        db.commit()
        for obj in created_objects:
            db.refresh(obj)
        return created_objects

    def get_by_screening(
        self, db: Session, screening_id: int
    ) -> List[SensorReading]:
        """Get all recorded sensor readings for a screening session, ordered chronologically."""
        return (
            db.query(SensorReading)
            .filter(SensorReading.screening_id == screening_id)
            .order_by(SensorReading.timestamp.asc(), SensorReading.id.asc())
            .all()
        )

    def get_by_screening_id(
        self, db: Session, screening_id: int
    ) -> List[SensorReading]:
        """Alias for get_by_screening."""
        return self.get_by_screening(db, screening_id)

    def get_latest(
        self, db: Session, screening_id: int
    ) -> Optional[SensorReading]:
        """Retrieve the most recent sensor reading for a screening session."""
        return (
            db.query(SensorReading)
            .filter(SensorReading.screening_id == screening_id)
            .order_by(SensorReading.timestamp.desc(), SensorReading.id.desc())
            .first()
        )


sensor_repository = SensorReadingRepository()
SensorRepository = SensorReadingRepository
