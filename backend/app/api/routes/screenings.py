from typing import List
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.schemas.screening import (
    ScreeningCreate,
    ScreeningResponse,
    ScreeningDetailResponse,
)
from app.services.screening_service import screening_service

router = APIRouter(prefix="/screenings", tags=["Screenings"])


@router.post(
    "",
    response_model=ScreeningResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Start a new screening session",
)
def create_screening(
    screening_in: ScreeningCreate,
    db: Session = Depends(get_db),
):
    return screening_service.start_screening(db, screening_in)


@router.get(
    "",
    response_model=List[ScreeningResponse],
    summary="Retrieve all screening sessions",
)
def get_screenings(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
):
    return screening_service.get_all_screenings(db, skip=skip, limit=limit)


@router.get(
    "/{screening_id}",
    response_model=ScreeningDetailResponse,
    summary="Get full screening details including sensor readings and questionnaire",
)
def get_screening(
    screening_id: int,
    db: Session = Depends(get_db),
):
    return screening_service.get_screening(db, screening_id)


@router.put(
    "/{screening_id}/complete",
    response_model=ScreeningResponse,
    summary="Mark a screening session as completed",
)
def complete_screening(
    screening_id: int,
    db: Session = Depends(get_db),
):
    return screening_service.complete_screening(db, screening_id)
