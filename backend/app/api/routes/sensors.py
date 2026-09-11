from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.schemas.sensor import (
    SensorReadingCreate,
    SensorReadingBulkCreate,
    SensorReadingResponse,
)
from app.services.screening_service import screening_service

router = APIRouter(prefix="/screenings", tags=["Sensors"])


@router.post(
    "/{screening_id}/sensor-data",
    response_model=SensorReadingResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Record a single sensor reading",
)
def create_sensor_data(
    screening_id: int,
    reading_in: SensorReadingCreate,
    db: Session = Depends(get_db),
):
    return screening_service.add_sensor_reading(db, screening_id, reading_in)


@router.post(
    "/{screening_id}/sensor-readings",
    response_model=SensorReadingResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Record a single sensor reading (alias)",
    include_in_schema=False,
)
def create_sensor_reading_alias(
    screening_id: int,
    reading_in: SensorReadingCreate,
    db: Session = Depends(get_db),
):
    return screening_service.add_sensor_reading(db, screening_id, reading_in)


@router.post(
    "/{screening_id}/sensor-data/bulk",
    response_model=List[SensorReadingResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Bulk insert multiple continuous sensor readings",
)
def create_bulk_sensor_data(
    screening_id: int,
    bulk_in: SensorReadingBulkCreate,
    db: Session = Depends(get_db),
):
    return screening_service.add_multiple_sensor_readings(
        db, screening_id, bulk_in.readings
    )


@router.get(
    "/{screening_id}/sensor-data",
    response_model=List[SensorReadingResponse],
    summary="Get all recorded sensor readings for a screening session",
)
def get_sensor_data(
    screening_id: int,
    db: Session = Depends(get_db),
):
    return screening_service.get_sensor_readings(db, screening_id)


@router.get(
    "/{screening_id}/sensor-readings",
    response_model=List[SensorReadingResponse],
    summary="Get all recorded sensor readings (alias)",
    include_in_schema=False,
)
def get_sensor_readings_alias(
    screening_id: int,
    db: Session = Depends(get_db),
):
    return screening_service.get_sensor_readings(db, screening_id)


@router.get(
    "/{screening_id}/sensor-data/latest",
    response_model=SensorReadingResponse,
    summary="Get the most recent sensor reading for a screening session",
)
def get_latest_sensor_data(
    screening_id: int,
    db: Session = Depends(get_db),
):
    return screening_service.get_latest_sensor_reading(db, screening_id)
