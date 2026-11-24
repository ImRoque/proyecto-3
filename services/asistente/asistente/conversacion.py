"""Arma la respuesta del chat: intención con el modelo y datos vivos por API."""
import logging

from . import extraccion, textos
from .adaptador import AdaptadorChat
from .clientes import ClientePedidos, ClienteRecomendar, ServicioNoDisponible
from .clientes import SolicitudRechazada

logger = logging.getLogger(__name__)

# Por debajo de esta probabilidad la intención es `desconocida` (docs/api.md).
UMBRAL_CONFIANZA = 0.40

# Medidas que se suponen si el mensaje no las trae (caja chica). La respuesta lo avisa.
MEDIDAS_POR_DEFECTO = {"largo": 20.0, "ancho": 15.0, "alto": 10.0}


class Asistente:

    def __init__(self, modelo, pedidos=None, recomendar=None, adaptador=None):
        self.modelo = modelo
        self.pedidos = pedidos or ClientePedidos()
        self.recomendar = recomendar or ClienteRecomendar()
        self.adaptador = adaptador or AdaptadorChat()

    def responder(self, mensaje):
        """Devuelve {"intencion", "respuesta"}."""
        intencion = self.detectar_intencion(mensaje)
        manejador = {
            "rastrear": self._rastrear,
            "recomendar": self._recomendar,
            "cotizar": lambda _: textos.COTIZAR,
            "horarios": lambda _: textos.HORARIOS,
            "saludo": lambda _: textos.SALUDO,
        }.get(intencion, lambda _: textos.DESCONOCIDA)
        return {"intencion": intencion, "respuesta": manejador(mensaje)}

    def detectar_intencion(self, mensaje):
        # Un folio válido en el mensaje basta para rastrear: así funciona responder solo
        # "PQ-20261117-7KQ3" después de que el asistente pidió el folio.
        if extraccion.extraer_folio(mensaje):
            return "rastrear"
        intencion, confianza = self.modelo.clasificar(mensaje)
        return intencion if confianza >= UMBRAL_CONFIANZA else "desconocida"

    def _rastrear(self, mensaje):
        folio = extraccion.extraer_folio(mensaje)
        if not folio:
            return textos.PEDIR_FOLIO
        try:
            pedido = self.pedidos.consultar(folio)
        except ServicioNoDisponible as error:
            logger.warning("No se pudo consultar pedidos: %s", error)
            return textos.PEDIDOS_NO_DISPONIBLE
        if pedido is None:
            return textos.FOLIO_NO_ENCONTRADO.format(folio=folio)
        return self.adaptador.pedido(pedido)

    def _recomendar(self, mensaje):
        peso = extraccion.extraer_peso_kg(mensaje)
        distancia = extraccion.extraer_distancia_km(mensaje)
        faltantes = [nombre for nombre, valor in
                     (("el peso (por ejemplo 3 kg)", peso),
                      ("la distancia (por ejemplo 5 km)", distancia)) if valor is None]
        if faltantes:
            return textos.PEDIR_DATOS_RECOMENDAR.format(faltantes=" y ".join(faltantes))

        medidas = extraccion.extraer_dimensiones_cm(mensaje)
        supuestas = None
        if medidas is None:
            medidas = supuestas = dict(MEDIDAS_POR_DEFECTO)
        try:
            datos = self.recomendar.recomendar(
                peso, distancia, extraccion.extraer_urgente(mensaje), medidas,
            )
        except SolicitudRechazada as error:
            return self.adaptador.recomendacion_rechazada(error.codigo, error.detalle)
        except ServicioNoDisponible as error:
            logger.warning("No se pudo consultar recomendar: %s", error)
            return textos.RECOMENDAR_NO_DISPONIBLE
        return self.adaptador.recomendacion(datos, medidas_supuestas=supuestas)
