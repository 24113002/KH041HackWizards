"""Database seed script for demo/test data."""

import logging
from app.core.database import SessionLocal, init_db
from app.models.patient import Patient

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("seed")

DEMO_PATIENTS = [
    {
        "full_name": "Rahul Patil",
        "age": 52,
        "gender": "Male",
        "village": "Satara",
        "occupation": "Farmer",
        "smoking_status": "former",
    },
    {
        "full_name": "Anita Sharma",
        "age": 46,
        "gender": "Female",
        "village": "Khed",
        "occupation": "Homemaker",
        "smoking_status": "never",
    },
    {
        "full_name": "Vijay More",
        "age": 61,
        "gender": "Male",
        "village": "Wai",
        "occupation": "Construction Worker",
        "smoking_status": "current",
    },
]


def seed_data():
    init_db()
    db = SessionLocal()
    try:
        existing_count = db.query(Patient).count()
        if existing_count > 0:
            logger.info("Database already seeded (%d patients found). Skipping.", existing_count)
            return

        for data in DEMO_PATIENTS:
            patient = Patient(**data)
            db.add(patient)
        db.commit()
        logger.info("Successfully seeded %d demo patients.", len(DEMO_PATIENTS))
    finally:
        db.close()


if __name__ == "__main__":
    seed_data()
