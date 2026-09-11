from typing import Optional
from sqlalchemy.orm import Session
from app.models.questionnaire import QuestionnaireResponse
from app.schemas.questionnaire import QuestionnaireCreate


class QuestionnaireRepository:
    def get_by_screening_id(
        self, db: Session, screening_id: int
    ) -> Optional[QuestionnaireResponse]:
        return (
            db.query(QuestionnaireResponse)
            .filter(QuestionnaireResponse.screening_id == screening_id)
            .first()
        )

    def create_or_update(
        self, db: Session, screening_id: int, questionnaire_in: QuestionnaireCreate
    ) -> QuestionnaireResponse:
        existing = self.get_by_screening_id(db, screening_id)
        if existing:
            update_data = questionnaire_in.model_dump(exclude_unset=True)
            for field, value in update_data.items():
                setattr(existing, field, value)
            db.add(existing)
            db.commit()
            db.refresh(existing)
            return existing

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
        )
        db.add(db_questionnaire)
        db.commit()
        db.refresh(db_questionnaire)
        return db_questionnaire


questionnaire_repository = QuestionnaireRepository()
