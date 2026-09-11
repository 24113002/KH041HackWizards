from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict, Field
from app.schemas.patient import PatientResponse
from app.schemas.sensor import SensorReadingResponse
from app.schemas.questionnaire import QuestionnaireResponseSchema
from app.schemas.risk_result import RiskResultResponse


class ScreeningBase(BaseModel):
    patient_id: int = Field(..., description="ID of the patient being screened")


class ScreeningCreate(ScreeningBase):
    pass


class ScreeningUpdate(BaseModel):
    status: Optional[str] = Field(None, description="Status: in_progress, completed, cancelled")
    risk_score: Optional[float] = Field(None, ge=0.0, le=100.0)
    risk_category: Optional[str] = Field(None)
    completed_at: Optional[datetime] = None


class ScreeningResponse(ScreeningBase):
    id: int
    started_at: datetime
    completed_at: Optional[datetime] = None
    status: str
    risk_score: Optional[float] = None
    risk_category: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class ScreeningDetailResponse(ScreeningResponse):
    sensor_readings: List[SensorReadingResponse] = []
    questionnaire_response: Optional[QuestionnaireResponseSchema] = None
    risk_result: Optional[RiskResultResponse] = None

    model_config = ConfigDict(from_attributes=True)


class CompleteScreeningResponse(BaseModel):
    patient: Optional[PatientResponse] = None
    screening: ScreeningResponse
    sensor_readings: List[SensorReadingResponse] = []
    questionnaire: Optional[QuestionnaireResponseSchema] = None
    risk_result: Optional[RiskResultResponse] = None

    model_config = ConfigDict(from_attributes=True)


# Alias
ScreeningCompleteResponse = CompleteScreeningResponse
