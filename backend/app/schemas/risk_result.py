from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict, Field


class RiskResultBase(BaseModel):
    risk_score: Optional[float] = Field(None, ge=0.0, le=100.0, description="Estimated risk score (0-100)")
    risk_category: Optional[str] = Field(None, description="Screening category: Low Risk, Moderate Risk, Higher Risk")
    contributing_factors: Optional[List[str]] = Field(default_factory=list, description="Key factors identified")
    recommendation: Optional[str] = Field(None, description="Actionable screening recommendation / clinical advisory")


class RiskResultCreate(RiskResultBase):
    screening_id: int


class RiskResultResponse(RiskResultBase):
    id: int
    screening_id: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
