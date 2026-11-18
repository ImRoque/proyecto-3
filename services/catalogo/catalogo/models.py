"""Modelos del catálogo (docs/api.md, sección "Catálogo").

Las vistas no usan estos modelos directamente: pasan por catalogo/repositorio.py.
"""
from django.db import models


class MedioEntrega(models.Model):
    """Medio con el que se entrega un paquete: camioneta, motocicleta, bicicleta o dron."""

    clave = models.CharField(max_length=30, unique=True)
    nombre = models.CharField(max_length=60)
    descripcion = models.CharField(max_length=200)
    peso_max_kg = models.FloatField()
    distancia_max_km = models.FloatField()
    velocidad_kmh = models.FloatField()
    costo_base = models.FloatField(help_text="Costo fijo por envío, en MXN.")
    costo_por_km = models.FloatField(help_text="Costo por kilómetro, en MXN.")

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return self.nombre


class TipoServicio(models.Model):
    """Nivel de servicio: estándar, express o mismo día."""

    clave = models.CharField(max_length=30, unique=True)
    nombre = models.CharField(max_length=60)
    descripcion = models.CharField(max_length=200)
    tiempo_max_horas = models.PositiveIntegerField()
    multiplicador_costo = models.FloatField()

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return self.nombre
