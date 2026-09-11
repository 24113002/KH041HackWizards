from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Float, Text, JSON, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class RiskResult(Base):
    __tablename__ = "risk_results"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    screening_id = Column(Integer, ForeignKey("screening_sessions.id", ondelete="CASCADE"), nullable=False, unique=True, index=True)
    risk_score = Column(Float, nullable=True)
    risk_category = Column(String(50), nullable=True)
    contributing_factors = Column(JSON, nullable=True)
    recommendation = Column(Text, nullable=True)
    created_at = Column(DateTime, default=utc_now, nullable=False)

    # Relationships
    screening = relationship("ScreeningSession", back_populates="risk_result")
