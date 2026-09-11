from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class ScreeningSession(Base):
    __tablename__ = "screening_sessions"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    patient_id = Column(Integer, ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, index=True)
    started_at = Column(DateTime, default=utc_now, nullable=False, index=True)
    completed_at = Column(DateTime, nullable=True)
    status = Column(String(30), default="in_progress", nullable=False, index=True)  # in_progress, completed, cancelled
    risk_score = Column(Float, nullable=True)
    risk_category = Column(String(50), nullable=True)

    # Relationships
    patient = relationship("Patient", back_populates="screenings")
    sensor_readings = relationship(
        "SensorReading",
        back_populates="screening",
        cascade="all, delete-orphan",
        order_by="SensorReading.timestamp",
    )
    questionnaire_response = relationship(
        "QuestionnaireResponse",
        back_populates="screening",
        uselist=False,
        cascade="all, delete-orphan",
    )
    risk_result = relationship(
        "RiskResult",
        back_populates="screening",
        uselist=False,
        cascade="all, delete-orphan",
    )
