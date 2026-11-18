"""Rutas del servicio recomendar. Todas cuelgan del prefijo /api/recomendar/."""
from django.urls import include, path

urlpatterns = [
    path("api/recomendar/", include("recomendar.urls")),
]
