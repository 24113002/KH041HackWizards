import logging
from typing import Generator
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker, Session
from app.core.config import settings

logger = logging.getLogger(__name__)

# Ensure data directory exists
settings.DATABASE_PATH.parent.mkdir(parents=True, exist_ok=True)

# SQLite engine configuration
engine = create_engine(
    settings.DATABASE_URL,
    connect_args={"check_same_thread": False},
    echo=False,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db() -> Generator[Session, None, None]:
    """Dependency for obtaining database sessions per request."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db() -> None:
    """Initialize database tables."""
    # Import all models to ensure they are registered with Base.metadata
    from app.models import patient, screening, sensor_reading, questionnaire, risk_result  # noqa: F401

    logger.info("Initializing database schema at %s", settings.DATABASE_URL)
    Base.metadata.create_all(bind=engine)
    logger.info("Database initialized successfully.")
