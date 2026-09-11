from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field


class SensorReadingBase(BaseModel):
    spo2: Optional[float] = Field(None, ge=0.0, le=100.0, description="Blood oxygen saturation percentage (SpO2)")
    heart_rate: Optional[float] = Field(None, ge=0.0, le=300.0, description="Heart rate in BPM")
    pressure: Optional[float] = Field(None, description="Airway/exhalation pressure measurement")
    cough_activity: Optional[float] = Field(None, description="Acoustic cough activity index")


class SensorReadingCreate(SensorReadingBase):
    pass


class SensorReadingResponse(SensorReadingBase):
    id: int
    screening_id: int
    timestamp: datetime

    model_config = ConfigDict(from_attributes=True)
