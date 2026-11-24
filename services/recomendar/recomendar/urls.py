from django.urls import path

from . import views

urlpatterns = [
    path("", views.recomendar, name="recomendar"),
    path("health/", views.health, name="health"),
]
