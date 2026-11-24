from django.urls import path

from . import views

urlpatterns = [
    path("", views.conversar, name="conversar"),
    path("health/", views.health, name="health"),
]
