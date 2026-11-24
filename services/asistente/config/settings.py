"""Configuración del servicio asistente.

Todo lo que cambia entre entornos se lee de variables de entorno.
Ver .env.example para la lista completa.
"""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent


def _env_bool(nombre, defecto=False):
    valor = os.environ.get(nombre)
    if valor is None:
        return defecto
    return valor.strip().lower() in ("1", "true", "yes", "si")


def _env_lista(nombre, defecto=""):
    valor = os.environ.get(nombre, defecto)
    return [elemento.strip() for elemento in valor.split(",") if elemento.strip()]


# Valor de respaldo solo para correr el servicio suelto en desarrollo.
SECRET_KEY = os.environ.get("SECRET_KEY", "solo-para-desarrollo-cambiar-en-otros-entornos")

DEBUG = _env_bool("DEBUG", False)

ALLOWED_HOSTS = _env_lista("ALLOWED_HOSTS", "localhost,127.0.0.1")

INSTALLED_APPS = [
    "asistente",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.middleware.common.CommonMiddleware",
]

ROOT_URLCONF = "config.urls"

WSGI_APPLICATION = "config.wsgi.application"

# Base de datos: PostgreSQL si hay DB_NAME; si no, SQLite para correr el servicio suelto.
if os.environ.get("DB_NAME"):
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": os.environ["DB_NAME"],
            "USER": os.environ.get("DB_USER", ""),
            "PASSWORD": os.environ.get("DB_PASSWORD", ""),
            "HOST": os.environ.get("DB_HOST", "localhost"),
            "PORT": os.environ.get("DB_PORT", "5432"),
        }
    }
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "db.sqlite3",
        }
    }

LANGUAGE_CODE = "es-mx"
TIME_ZONE = "America/Mexico_City"
USE_I18N = True
USE_TZ = True

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# Servicios que consulta el asistente: nombres internos de Docker Compose.
PEDIDOS_URL = os.environ.get("PEDIDOS_URL", "http://pedidos:8000")
RECOMENDAR_URL = os.environ.get("RECOMENDAR_URL", "http://recomendar:8000")
# Tiempo límite en segundos de cada llamada a otro servicio (docs/api.md, "Asistente").
SERVICIOS_TIMEOUT = float(os.environ.get("SERVICIOS_TIMEOUT", "3"))
