from django.urls import path

from . import views

urlpatterns = [
    path("health/", views.health, name="health"),
    path("medios/", views.listar_medios, name="listar_medios"),
    path("medios/<str:clave>/", views.detalle_medio, name="detalle_medio"),
    path("tipos-servicio/", views.listar_tipos_servicio, name="listar_tipos_servicio"),
]
