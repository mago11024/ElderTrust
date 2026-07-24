from typing import Literal

from fastapi import FastAPI
from pydantic import BaseModel

from app.common.config import get_settings


class HealthResponse(BaseModel):
    status: Literal["ok"]


settings = get_settings()
app = FastAPI(title="安信伴老 API", version="0.1.0")


@app.get("/health", response_model=HealthResponse, tags=["system"])
def health() -> HealthResponse:
    return HealthResponse(status="ok")
