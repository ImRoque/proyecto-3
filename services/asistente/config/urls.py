"""Rutas del servicio asistente. Todas cuelgan del prefijo /api/asistente/."""
from django.urls import include, path

urlpatterns = [
    path("api/asistente/", include("asistente.urls")),
]
