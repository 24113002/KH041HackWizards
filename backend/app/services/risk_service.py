"""Risk Assessment Service Interface & Foundation.

IMPORTANT MEDICAL & REGULATORY DISCLAIMER:
SwasthAI is a screening-support system designed for rural frontline health workers,
NOT a diagnostic medical device. It does NOT confirm or diagnose COPD.

Approved Terminology:
- "Risk Screening"
- "Low Risk" / "Moderate Risk" / "Higher Risk"
- "Clinical Evaluation Recommended"
- "Confirmatory testing may be required (e.g., Spirometry)."
"""

import logging
from abc import ABC, abstractmethod
from typing import List, Optional
from app.schemas.questionnaire import QuestionnaireResponseSchema
from app.schemas.sensor import SensorReadingResponse
from app.schemas.risk_result import RiskResultResponse

logger = logging.getLogger(__name__)


class IRiskAssessmentEngine(ABC):
    """Interface for pluggable risk assessment engines."""

    @abstractmethod
    def assess(
        self,
        questionnaire: Optional[QuestionnaireResponseSchema] = None,
        sensor_readings: Optional[List[SensorReadingResponse]] = None,
    ) -> dict:
        """Evaluate inputs and return risk assessment outcome."""
        pass


class PlaceholderRiskAssessmentService(IRiskAssessmentEngine):
    """Placeholder / Mock implementation for Phase B1 preparation."""

    def assess(
        self,
        questionnaire: Optional[QuestionnaireResponseSchema] = None,
        sensor_readings: Optional[List[SensorReadingResponse]] = None,
    ) -> dict:
        logger.info("Executing risk assessment evaluation placeholder.")

        # Baseline default structure
        return {
            "risk_score": None,
            "risk_category": "Pending Assessment",
            "contributing_factors": [],
            "recommendation": "Screening in progress. Clinical evaluation recommended if symptoms persist.",
        }


risk_assessment_service = PlaceholderRiskAssessmentService()
