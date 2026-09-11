from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field


class PatientBase(BaseModel):
    full_name: str = Field(..., min_length=1, max_length=100, description="Full name of the patient")
    age: int = Field(..., ge=0, le=130, description="Age in years")
    gender: str = Field(..., min_length=1, max_length=20, description="Gender (e.g., Male, Female, Other)")
    village: Optional[str] = Field(None, max_length=100, description="Village or locality")
    occupation: Optional[str] = Field(None, max_length=100, description="Occupation")
    smoking_status: Optional[str] = Field(None, max_length=50, description="Smoking status (e.g., never, former, current)")


class PatientCreate(PatientBase):
    pass


class PatientUpdate(BaseModel):
    full_name: Optional[str] = Field(None, min_length=1, max_length=100)
    age: Optional[int] = Field(None, ge=0, le=130)
    gender: Optional[str] = Field(None, min_length=1, max_length=20)
    village: Optional[str] = Field(None, max_length=100)
    occupation: Optional[str] = Field(None, max_length=100)
    smoking_status: Optional[str] = Field(None, max_length=50)


class PatientResponse(PatientBase):
    id: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
