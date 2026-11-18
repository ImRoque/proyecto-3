"""Rutas del servicio pedidos. Todas cuelgan del prefijo /api/pedidos/."""
from django.urls import include, path

urlpatterns = [
    path("api/pedidos/", include("pedidos.urls")),
]
