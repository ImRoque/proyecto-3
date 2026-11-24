"""Rutas del servicio asistente. Todas cuelgan del prefijo /api/asistente/."""
from django.urls import include, path

urlpatterns = [
    path("api/asistente/", include("asistente.urls")),
]

# Rutas inexistentes responden con el formato de error de docs/api.md.
handler404 = "asistente.errores.ruta_no_encontrada"
