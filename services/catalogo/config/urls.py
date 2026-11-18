"""Rutas del servicio catalogo. Todas cuelgan del prefijo /api/catalogo/."""
from django.urls import include, path

urlpatterns = [
    path("api/catalogo/", include("catalogo.urls")),
]

# Rutas inexistentes responden con el formato de error de docs/api.md.
handler404 = "catalogo.errores.ruta_no_encontrada"
