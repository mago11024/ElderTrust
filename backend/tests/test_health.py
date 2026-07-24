from pathlib import Path

from fastapi.testclient import TestClient


def test_health_endpoint_reports_service_is_available() -> None:
    assert Path("app/main.py").is_file(), "FastAPI application is not implemented"

    from app.main import app

    response = TestClient(app).get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
