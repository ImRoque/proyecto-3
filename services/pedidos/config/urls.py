"""Rutas del servicio pedidos. Todas cuelgan del prefijo /api/pedidos/."""
from django.urls import include, path

urlpatterns = [
    path("api/pedidos/", include("pedidos.urls")),
]

# Rutas inexistentes responden con el formato de error de docs/api.md.
handler404 = "pedidos.errores.ruta_no_encontrada"
