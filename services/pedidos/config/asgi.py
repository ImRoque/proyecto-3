"""Punto de entrada ASGI (no se usa por ahora; lo genera Django por defecto)."""
import os

from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

application = get_asgi_application()
