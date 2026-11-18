"""Capa de acceso a datos de pedidos (patrón Repository).

Las vistas y la confirmación hablan con esta clase y reciben diccionarios con los campos
exactos del contrato de docs/api.md. El ORM, las transacciones y la forma del JSON quedan
en un solo lugar.
"""
from django.db import IntegrityError, transaction
from django.utils import timezone

from . import estados
from .errores import ErrorApi
from .folio import generar_folio
from .models import Pedido

INTENTOS_FOLIO = 5


class ClaveYaRegistrada(Exception):
    """Otra petición guardó primero un pedido con la misma Idempotency-Key."""


def _fecha_hora(valor):
    return timezone.localtime(valor).isoformat(timespec="seconds")


class PedidoRepositorio:

    @staticmethod
    def _a_completo(pedido):
        """Respuesta del registro de un pedido."""
        return {
            "folio": pedido.folio,
            "estado": pedido.estado,
            "origen": pedido.origen,
            "destino": pedido.destino,
            "distancia_km": pedido.distancia_km,
            "peso_kg": pedido.peso_kg,
            "dimensiones_cm": {
                "largo": pedido.largo_cm,
                "ancho": pedido.ancho_cm,
                "alto": pedido.alto_cm,
            },
            "urgente": pedido.urgente,
            "seguro": pedido.seguro,
            "fecha_limite": pedido.fecha_limite.isoformat(),
            "medio": pedido.medio,
            "tipo_servicio": pedido.tipo_servicio,
            "costo": float(pedido.costo),
            "moneda": "MXN",
            "fecha_creacion": _fecha_hora(pedido.fecha_creacion),
        }

    @staticmethod
    def _a_minimo(pedido):
        """Datos mínimos para rastrear: sin origen, destino, peso, dimensiones, seguro ni costo."""
        return {
            "folio": pedido.folio,
            "estado": pedido.estado,
            "medio": pedido.medio,
            "tipo_servicio": pedido.tipo_servicio,
            "fecha_creacion": _fecha_hora(pedido.fecha_creacion),
            "fecha_limite": pedido.fecha_limite.isoformat(),
            "actualizado_en": _fecha_hora(pedido.actualizado_en),
        }

    def buscar_por_clave(self, idempotency_key):
        """Devuelve (huella_cuerpo, pedido completo) del pedido con esa clave, o None."""
        pedido = Pedido.objects.filter(idempotency_key=idempotency_key).first()
        if pedido is None:
            return None
        return pedido.huella_cuerpo, self._a_completo(pedido)

    def crear(self, datos, costo, idempotency_key, huella_cuerpo):
        """Guarda un pedido nuevo con folio único y devuelve el pedido completo.

        Lanza ClaveYaRegistrada si la restricción única de la base detecta que la clave ya
        existe (dos peticiones casi al mismo tiempo). Si choca el folio, genera otro.
        """
        dimensiones = datos["dimensiones_cm"]
        for _ in range(INTENTOS_FOLIO):
            try:
                with transaction.atomic():
                    pedido = Pedido.objects.create(
                        folio=generar_folio(timezone.localdate()),
                        estado=estados.CREADO,
                        origen=datos["origen"],
                        destino=datos["destino"],
                        distancia_km=datos["distancia_km"],
                        peso_kg=datos["peso_kg"],
                        largo_cm=dimensiones["largo"],
                        ancho_cm=dimensiones["ancho"],
                        alto_cm=dimensiones["alto"],
                        urgente=datos["urgente"],
                        seguro=datos["seguro"],
                        fecha_limite=datos["fecha_limite"],
                        medio=datos["medio"],
                        tipo_servicio=datos["tipo_servicio"],
                        costo=costo,
                        idempotency_key=idempotency_key,
                        huella_cuerpo=huella_cuerpo,
                    )
                return self._a_completo(pedido)
            except IntegrityError:
                if Pedido.objects.filter(idempotency_key=idempotency_key).exists():
                    raise ClaveYaRegistrada()
                # Si no fue la clave, chocó el folio: se intenta con otro.
        raise RuntimeError("No se pudo generar un folio único")

    def obtener(self, folio):
        """Devuelve los datos mínimos del pedido con ese folio, o None si no existe."""
        pedido = Pedido.objects.filter(folio=folio).first()
        return self._a_minimo(pedido) if pedido else None

    def cambiar_estado(self, folio, nuevo):
        """Cambia el estado si la transición es válida y devuelve los datos mínimos.

        Bloquea la fila mientras decide, para que dos cambios simultáneos no se pisen.
        """
        with transaction.atomic():
            pedido = Pedido.objects.select_for_update().filter(folio=folio).first()
            if pedido is None:
                raise ErrorApi("no_encontrado", f"No existe el pedido con folio {folio}", 404)
            anterior = pedido.estado
            if not estados.transicion_valida(anterior, nuevo):
                raise ErrorApi(
                    "transicion_invalida",
                    f"Un pedido {anterior} no puede pasar a {nuevo}",
                    409,
                )
            pedido.estado = nuevo
            pedido.save(update_fields=["estado", "actualizado_en"])
        minimo = self._a_minimo(pedido)
        # Mismo orden que el contrato: folio, estado_anterior, estado, ...
        return {"folio": minimo.pop("folio"), "estado_anterior": anterior, **minimo}
