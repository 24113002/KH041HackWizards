import os
from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict

# Project root directory (backend/)
BASE_DIR = Path(__file__).resolve().parent.parent.parent


class Settings(BaseSettings):
    PROJECT_NAME: str = "SwasthAI Backend"
    PROJECT_DESCRIPTION: str = (
        "Offline COPD Risk Screening Backend for Rural Healthcare. "
        "Screening-support system, not a diagnostic medical device."
    )
    VERSION: str = "0.1.0"
    API_V1_STR: str = "/api"
    MODE: str = "offline"

    # Database
    DATABASE_PATH: Path = BASE_DIR / "data" / "swasthai.db"
    DATABASE_URL: str = f"sqlite:///{DATABASE_PATH.as_posix()}"

    # CORS
    CORS_ORIGINS: list[str] = [
        "http://localhost",
        "http://localhost:3000",
        "http://localhost:8000",
        "http://127.0.0.1",
        "http://127.0.0.1:8000",
        "*",  # Local Flutter & mobile emulator access
    ]

    model_config = SettingsConfigDict(
        env_file=".env",
        case_sensitive=True,
        extra="ignore",
    )


settings = Settings()
