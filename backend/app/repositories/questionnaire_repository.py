from typing import Optional, Union
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.models.questionnaire import QuestionnaireResponse
from app.schemas.questionnaire import QuestionnaireCreate


class QuestionnaireRepository:
    def get_by_screening(
        self, db: Session, screening_id: int
    ) -> Optional[QuestionnaireResponse]:
        """Retrieve the questionnaire response for a screening session."""
        return (
            db.query(QuestionnaireResponse)
            .filter(QuestionnaireResponse.screening_id == screening_id)
            .first()
        )

    def get_by_screening_id(
        self, db: Session, screening_id: int
    ) -> Optional[QuestionnaireResponse]:
        """Alias for get_by_screening."""
        return self.get_by_screening(db, screening_id)

    def create(
        self, db: Session, screening_id: int, questionnaire_in: QuestionnaireCreate
    ) -> QuestionnaireResponse:
        """Create and persist questionnaire response, avoiding duplicates."""
        existing = self.get_by_screening(db, screening_id)
        if existing:
            return self.update(db, screening_id, questionnaire_in)

        db_questionnaire = QuestionnaireResponse(
            screening_id=screening_id,
            smoking_status=questionnaire_in.smoking_status,
            years_smoked=questionnaire_in.years_smoked,
            cigarettes_per_day=questionnaire_in.cigarettes_per_day,
            biomass_exposure=questionnaire_in.biomass_exposure,
            breathlessness=questionnaire_in.breathlessness,
            chronic_cough=questionnaire_in.chronic_cough,
            phlegm=questionnaire_in.phlegm,
            wheezing=questionnaire_in.wheezing,
            recurrent_respiratory_problems=questionnaire_in.recurrent_respiratory_problems,
            created_at=datetime.now(timezone.utc),
        )
        db.add(db_questionnaire)
        db.commit()
        db.refresh(db_questionnaire)
        return db_questionnaire

    def update(
        self,
        db: Session,
        screening_id: int,
        data: Union[QuestionnaireCreate, dict],
    ) -> Optional[QuestionnaireResponse]:
        """Update existing questionnaire response for a screening session."""
        existing = self.get_by_screening(db, screening_id)
        if not existing:
            return None

        if isinstance(data, dict):
            update_data = data
        else:
            update_data = data.model_dump(exclude_unset=True)

        for field, value in update_data.items():
            if hasattr(existing, field):
                setattr(existing, field, value)

        db.add(existing)
        db.commit()
        db.refresh(existing)
        return existing

    def create_or_update(
        self, db: Session, screening_id: int, questionnaire_in: QuestionnaireCreate
    ) -> QuestionnaireResponse:
        """Upsert questionnaire response for screening session."""
        existing = self.get_by_screening(db, screening_id)
        if existing:
            return self.update(db, screening_id, questionnaire_in)
        return self.create(db, screening_id, questionnaire_in)


questionnaire_repository = QuestionnaireRepository()
