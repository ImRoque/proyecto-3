"""Modelo del pedido (docs/api.md, sección "Pedidos").

Las vistas no usan este modelo directamente: pasan por pedidos/repositorio.py.
"""
from django.db import models

from . import estados


class Pedido(models.Model):
    folio = models.CharField(max_length=16, unique=True)
    estado = models.CharField(
        max_length=10,
        choices=[(e, e) for e in estados.ESTADOS],
        default=estados.CREADO,
    )
    origen = models.CharField(max_length=200)
    destino = models.CharField(max_length=200)
    distancia_km = models.FloatField()
    peso_kg = models.FloatField()
    largo_cm = models.FloatField()
    ancho_cm = models.FloatField()
    alto_cm = models.FloatField()
    urgente = models.BooleanField()
    seguro = models.BooleanField()
    fecha_limite = models.DateField()
    medio = models.CharField(max_length=30)
    tipo_servicio = models.CharField(max_length=30)
    costo = models.DecimalField(
        max_digits=12, decimal_places=2, help_text="Costo calculado al crear, en MXN."
    )
    # La restricción única es la que evita duplicados aunque lleguen dos peticiones a la vez.
    idempotency_key = models.UUIDField(unique=True)
    huella_cuerpo = models.CharField(
        max_length=64, help_text="SHA-256 del cuerpo normalizado de la solicitud."
    )
    fecha_creacion = models.DateTimeField(auto_now_add=True)
    actualizado_en = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return self.folio
