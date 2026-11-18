"""Rutas del servicio catalogo. Todas cuelgan del prefijo /api/catalogo/."""
from django.urls import include, path

urlpatterns = [
    path("api/catalogo/", include("catalogo.urls")),
]
