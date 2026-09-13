FROM python:3.13 AS builder

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt


FROM python:3.13-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

RUN groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid 10001 --create-home app

COPY --from=builder /usr/local/lib/python3.13/site-packages \
    /usr/local/lib/python3.13/site-packages

COPY --from=builder /usr/local/bin/ \
    /usr/local/bin/

COPY --chown=app:app . .

USER 10001:10001

EXPOSE 8000

CMD ["sh", "./docker/entrypoint.sh"]