from typing import List
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.schemas.screening import (
    ScreeningCreate,
    ScreeningResponse,
    ScreeningDetailResponse,
    CompleteScreeningResponse,
)
from app.schemas.risk_result import RiskResultResponse
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
    summary="Get screening details by ID",
)
def get_screening(
    screening_id: int,
    db: Session = Depends(get_db),
):
    return screening_service.get_screening(db, screening_id)


@router.post(
    "/{screening_id}/complete",
    response_model=ScreeningResponse,
    summary="Mark screening session as completed (POST)",
)
def complete_screening_post(
    screening_id: int,
    db: Session = Depends(get_db),
):
    return screening_service.complete_screening(db, screening_id)


@router.put(
    "/{screening_id}/complete",
    response_model=ScreeningResponse,
    summary="Mark screening session as completed (PUT)",
)
def complete_screening_put(
    screening_id: int,
    db: Session = Depends(get_db),
):
    return screening_service.complete_screening(db, screening_id)


@router.get(
    "/{screening_id}/complete",
    response_model=CompleteScreeningResponse,
    summary="Retrieve complete screening aggregation (patient, screening, sensor readings, questionnaire, risk result)",
)
def get_complete_screening(
    screening_id: int,
    db: Session = Depends(get_db),
):
    return screening_service.get_complete_screening(db, screening_id)


@router.get(
    "/{screening_id}/risk-result",
    response_model=RiskResultResponse,
    summary="Retrieve risk assessment result for a screening session",
)
def get_screening_risk_result(
    screening_id: int,
    db: Session = Depends(get_db),
):
    return screening_service.get_risk_result(db, screening_id)
