from app.api.routes.health import router as health_router
from app.api.routes.patients import router as patients_router
from app.api.routes.screenings import router as screenings_router
from app.api.routes.sensors import router as sensors_router
from app.api.routes.questionnaire import router as questionnaire_router

__all__ = [
    "health_router",
    "patients_router",
    "screenings_router",
    "sensors_router",
    "questionnaire_router",
]
