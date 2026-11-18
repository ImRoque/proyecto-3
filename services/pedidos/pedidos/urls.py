from django.urls import path

from . import views

urlpatterns = [
    path("", views.registrar, name="registrar"),
    path("health/", views.health, name="health"),
    path("<str:folio>/", views.consultar, name="consultar"),
    path("<str:folio>/estado/", views.cambiar_estado, name="cambiar_estado"),
]
