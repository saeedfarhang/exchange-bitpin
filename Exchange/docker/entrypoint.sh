#!/bin/bash
set -euo pipefail

python manage.py migrate
exec gunicorn \
  --bind :8000 \
  --timeout 90 \
  --graceful-timeout 30 \
  --keep-alive 5 \
  --max-requests 500 \
  --max-requests-jitter 50 \
  Exchange.wsgi:application
