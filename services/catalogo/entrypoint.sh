#!/bin/sh
# Prepara la base del catálogo y arranca el servicio.
# loaddata se puede repetir: los registros del fixture tienen pk fija y se actualizan.
set -e

python manage.py migrate --noinput
python manage.py loaddata catalogo_inicial.json

exec gunicorn config.wsgi:application --bind 0.0.0.0:8000
