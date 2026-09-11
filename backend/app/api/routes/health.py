from fastapi import APIRouter
from app.core.config import settings

router = APIRouter(tags=["Health"])


@router.get("/health", summary="Health Check Endpoint")
def get_health():
    """Health check for Flutter frontend and offline connectivity verification."""
    return {
        "status": "ok",
        "service": settings.PROJECT_NAME,
        "mode": settings.MODE,
    }
