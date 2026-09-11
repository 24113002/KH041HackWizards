from typing import List
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.models.sensor_reading import SensorReading
from app.schemas.sensor import SensorReadingCreate


class SensorRepository:
    def create(
        self, db: Session, screening_id: int, reading_in: SensorReadingCreate
    ) -> SensorReading:
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

    def get_by_screening_id(
        self, db: Session, screening_id: int
    ) -> List[SensorReading]:
        return (
            db.query(SensorReading)
            .filter(SensorReading.screening_id == screening_id)
            .order_by(SensorReading.timestamp.asc())
            .all()
        )


sensor_repository = SensorRepository()
