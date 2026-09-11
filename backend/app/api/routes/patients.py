from typing import List
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.schemas.patient import PatientCreate, PatientUpdate, PatientResponse
from app.schemas.screening import ScreeningResponse
from app.services.patient_service import patient_service
from app.services.screening_service import screening_service

router = APIRouter(prefix="/patients", tags=["Patients"])


@router.post(
    "",
    response_model=PatientResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new patient",
)
def create_patient(
    patient_in: PatientCreate,
    db: Session = Depends(get_db),
):
    return patient_service.create_patient(db, patient_in)


@router.get(
    "",
    response_model=List[PatientResponse],
    summary="Retrieve all registered patients",
)
def get_patients(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
):
    return patient_service.get_all_patients(db, skip=skip, limit=limit)


@router.get(
    "/search",
    response_model=List[PatientResponse],
    summary="Search patients by name",
)
def search_patients(
    q: str = Query(..., min_length=1, description="Patient name search query"),
    db: Session = Depends(get_db),
):
    return patient_service.search_patients(db, q)


@router.get(
    "/{patient_id}",
    response_model=PatientResponse,
    summary="Get patient details by ID",
)
def get_patient(
    patient_id: int,
    db: Session = Depends(get_db),
):
    return patient_service.get_patient(db, patient_id)


@router.put(
    "/{patient_id}",
    response_model=PatientResponse,
    summary="Update patient details",
)
def update_patient(
    patient_id: int,
    patient_in: PatientUpdate,
    db: Session = Depends(get_db),
):
    return patient_service.update_patient(db, patient_id, patient_in)


@router.delete(
    "/{patient_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a patient",
)
def delete_patient(
    patient_id: int,
    db: Session = Depends(get_db),
):
    patient_service.delete_patient(db, patient_id)
    return None


@router.get(
    "/{patient_id}/screenings",
    response_model=List[ScreeningResponse],
    summary="Get screening history for a specific patient",
)
def get_patient_screenings(
    patient_id: int,
    db: Session = Depends(get_db),
):
    return screening_service.get_patient_screenings(db, patient_id)
