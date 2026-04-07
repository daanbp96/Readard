"""CLI entry: run the API server (``readtard`` script)."""

import os


def main() -> None:
    import uvicorn

    host = os.environ.get("READTARD_HOST", "0.0.0.0")
    port = int(os.environ.get("READTARD_PORT", "8000"))
    reload = os.environ.get("READTARD_RELOAD", "1") == "1"
    uvicorn.run(
        "app.main:app",
        host=host,
        port=port,
        reload=reload,
    )
