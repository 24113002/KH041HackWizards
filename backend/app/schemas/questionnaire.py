from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field


class QuestionnaireBase(BaseModel):
    smoking_status: Optional[str] = Field(None, max_length=50, description="Smoking status (e.g., never, former, current)")
    years_smoked: Optional[int] = Field(None, ge=0, le=100, description="Number of years smoked")
    cigarettes_per_day: Optional[int] = Field(None, ge=0, le=200, description="Average cigarettes/bidis per day")
    biomass_exposure: bool = Field(False, description="Exposure to biomass fuel / chulha smoke")
    breathlessness: bool = Field(False, description="Experienced shortness of breath / dyspnea")
    chronic_cough: bool = Field(False, description="Chronic persistent cough")
    phlegm: bool = Field(False, description="Regular sputum / phlegm production")
    wheezing: bool = Field(False, description="Wheezing / whistling sound while breathing")
    recurrent_respiratory_problems: bool = Field(False, description="History of frequent chest infections/illnesses")


class QuestionnaireCreate(QuestionnaireBase):
    pass


class QuestionnaireResponseSchema(QuestionnaireBase):
    id: int
    screening_id: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
