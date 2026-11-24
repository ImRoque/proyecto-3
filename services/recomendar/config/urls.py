"""Rutas del servicio recomendar. Todas cuelgan del prefijo /api/recomendar/."""
from django.urls import include, path

urlpatterns = [
    path("api/recomendar/", include("recomendar.urls")),
]

# Rutas inexistentes responden con el formato de error de docs/api.md.
handler404 = "recomendar.errores.ruta_no_encontrada"
