from typing import Optional, Union, List
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.models.risk_result import RiskResult
from app.schemas.risk_result import RiskResultCreate, RiskResultBase


class RiskResultRepository:
    def get_by_screening(
        self, db: Session, screening_id: int
    ) -> Optional[RiskResult]:
        """Retrieve the risk screening assessment result for a screening session."""
        return (
            db.query(RiskResult)
            .filter(RiskResult.screening_id == screening_id)
            .first()
        )

    def get_by_screening_id(
        self, db: Session, screening_id: int
    ) -> Optional[RiskResult]:
        """Alias for get_by_screening."""
        return self.get_by_screening(db, screening_id)

    def create(
        self,
        db: Session,
        screening_id: int,
        result_in: Union[RiskResultCreate, RiskResultBase, dict],
    ) -> RiskResult:
        """Create and persist a risk result, updating if one already exists."""
        existing = self.get_by_screening(db, screening_id)
        if existing:
            return self.update(db, screening_id, result_in)

        if isinstance(result_in, dict):
            risk_score = result_in.get("risk_score")
            risk_category = result_in.get("risk_category")
            contributing_factors = result_in.get("contributing_factors", [])
            recommendation = result_in.get("recommendation")
        else:
            risk_score = result_in.risk_score
            risk_category = result_in.risk_category
            contributing_factors = result_in.contributing_factors or []
            recommendation = result_in.recommendation

        db_result = RiskResult(
            screening_id=screening_id,
            risk_score=risk_score,
            risk_category=risk_category,
            contributing_factors=contributing_factors,
            recommendation=recommendation,
            created_at=datetime.now(timezone.utc),
        )
        db.add(db_result)
        db.commit()
        db.refresh(db_result)
        return db_result

    def update(
        self,
        db: Session,
        screening_id: int,
        data: Union[RiskResultCreate, RiskResultBase, dict],
    ) -> Optional[RiskResult]:
        """Update existing risk result for a screening session."""
        existing = self.get_by_screening(db, screening_id)
        if not existing:
            return None

        if isinstance(data, dict):
            update_data = data
        else:
            update_data = data.model_dump(exclude_unset=True)

        for field, value in update_data.items():
            if hasattr(existing, field) and field != "id" and field != "screening_id":
                setattr(existing, field, value)

        db.add(existing)
        db.commit()
        db.refresh(existing)
        return existing

    def create_or_update(
        self,
        db: Session,
        screening_id: int,
        result_in: Union[RiskResultCreate, RiskResultBase, dict],
    ) -> RiskResult:
        """Upsert risk result record for screening session."""
        existing = self.get_by_screening(db, screening_id)
        if existing:
            return self.update(db, screening_id, result_in)
        return self.create(db, screening_id, result_in)


risk_result_repository = RiskResultRepository()
