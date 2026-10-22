FROM python:3.11-slim AS base

WORKDIR /app

COPY requirements.txt .
RUN python -m pip install --no-cache-dir --disable-pip-version-check -r requirements.txt
COPY app.py .

FROM base AS runtime
RUN groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app --home-dir /app app

USER 10001:10001
EXPOSE 5000
CMD ["python", "app.py"]

FROM base AS test
COPY tests/ ./tests/
CMD ["python", "-m", "unittest", "discover", "-s", "tests", "-v"]
