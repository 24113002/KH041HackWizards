from datetime import datetime, timezone
from sqlalchemy import Column, Integer, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class SensorReading(Base):
    __tablename__ = "sensor_readings"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    screening_id = Column(Integer, ForeignKey("screening_sessions.id", ondelete="CASCADE"), nullable=False, index=True)
    timestamp = Column(DateTime, default=utc_now, nullable=False)
    spo2 = Column(Float, nullable=True)
    heart_rate = Column(Float, nullable=True)
    pressure = Column(Float, nullable=True)
    cough_activity = Column(Float, nullable=True)

    # Relationships
    screening = relationship("ScreeningSession", back_populates="sensor_readings")
