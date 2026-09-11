from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class QuestionnaireResponse(Base):
    __tablename__ = "questionnaire_responses"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    screening_id = Column(Integer, ForeignKey("screening_sessions.id", ondelete="CASCADE"), nullable=False, unique=True, index=True)
    smoking_status = Column(String(50), nullable=True)
    years_smoked = Column(Integer, nullable=True)
    cigarettes_per_day = Column(Integer, nullable=True)
    biomass_exposure = Column(Boolean, default=False, nullable=False)
    breathlessness = Column(Boolean, default=False, nullable=False)
    chronic_cough = Column(Boolean, default=False, nullable=False)
    phlegm = Column(Boolean, default=False, nullable=False)
    wheezing = Column(Boolean, default=False, nullable=False)
    recurrent_respiratory_problems = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=utc_now, nullable=False)

    # Relationships
    screening = relationship("ScreeningSession", back_populates="questionnaire_response")
