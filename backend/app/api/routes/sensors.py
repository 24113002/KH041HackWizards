from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.schemas.sensor import SensorReadingCreate, SensorReadingResponse
from app.services.screening_service import screening_service

router = APIRouter(prefix="/screenings", tags=["Sensors"])


@router.post(
    "/{screening_id}/sensor-readings",
    response_model=SensorReadingResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Record sensor readings for a screening session (SpO2, Heart Rate, Pressure, Cough)",
)
def create_sensor_reading(
    screening_id: int,
    reading_in: SensorReadingCreate,
    db: Session = Depends(get_db),
):
    return screening_service.add_sensor_reading(db, screening_id, reading_in)


@router.get(
    "/{screening_id}/sensor-readings",
    response_model=List[SensorReadingResponse],
    summary="Get all recorded sensor readings for a screening session",
)
def get_sensor_readings(
    screening_id: int,
    db: Session = Depends(get_db),
):
    return screening_service.get_sensor_readings(db, screening_id)
