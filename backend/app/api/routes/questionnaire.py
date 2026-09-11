from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.schemas.questionnaire import (
    QuestionnaireCreate,
    QuestionnaireResponseSchema,
)
from app.services.screening_service import screening_service

router = APIRouter(prefix="/screenings", tags=["Questionnaire"])


@router.post(
    "/{screening_id}/questionnaire",
    response_model=QuestionnaireResponseSchema,
    status_code=status.HTTP_201_CREATED,
    summary="Submit or update questionnaire responses for a screening session",
)
def submit_questionnaire(
    screening_id: int,
    questionnaire_in: QuestionnaireCreate,
    db: Session = Depends(get_db),
):
    return screening_service.submit_questionnaire(db, screening_id, questionnaire_in)


@router.get(
    "/{screening_id}/questionnaire",
    response_model=QuestionnaireResponseSchema,
    summary="Get questionnaire responses for a screening session",
)
def get_questionnaire(
    screening_id: int,
    db: Session = Depends(get_db),
):
    return screening_service.get_questionnaire(db, screening_id)
