#!/bin/sh
# Prepara la base de pedidos y arranca el servicio.
set -e

python manage.py migrate --noinput

# Varios workers para atender peticiones en paralelo; la restricción única de
# Idempotency-Key evita duplicados aunque dos lleguen al mismo tiempo.
exec gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers "${GUNICORN_WORKERS:-3}"
