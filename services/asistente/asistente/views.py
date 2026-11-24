"""Vistas del asistente (docs/api.md, sección "Asistente").

Las vistas solo leen la petición y arman la respuesta. La conversación la resuelve
Asistente (conversacion.py) con el modelo ya cargado desde el inicio del servicio.
"""
import json
import logging

from . import modelo
from .conversacion import Asistente
from .errores import ErrorApi, datos_invalidos, mensaje_vacio, modelo_no_disponible
from .errores import respuesta_error, respuesta_json, ruta_no_encontrada

SERVICIO = "asistente"
MENSAJE_MAX = 500

logger = logging.getLogger(__name__)


def solo(metodo):
    """Solo acepta `metodo`. Otro método responde 404 ruta_no_encontrada (no hay 405)."""
    def decorador(vista):
        def envoltura(request, *args, **kwargs):
            if request.method != metodo:
                return ruta_no_encontrada(request)
            try:
                return vista(request, *args, **kwargs)
            except ErrorApi as error:
                return respuesta_error(error.codigo, error.detalle, error.status)

        envoltura.__name__ = vista.__name__
        envoltura.__doc__ = vista.__doc__
        return envoltura

    return decorador


def _leer_mensaje(cuerpo):
    try:
        datos = json.loads(cuerpo.decode("utf-8"))
    except (UnicodeDecodeError, ValueError):
        raise datos_invalidos("El cuerpo no es JSON válido")
    if not isinstance(datos, dict):
        raise datos_invalidos("El cuerpo debe ser un objeto JSON")

    mensaje = datos.get("mensaje")
    if mensaje is None:
        raise mensaje_vacio()
    if not isinstance(mensaje, str):
        raise datos_invalidos("mensaje debe ser un texto")
    mensaje = mensaje.strip()
    if not mensaje:
        raise mensaje_vacio()
    if len(mensaje) > MENSAJE_MAX:
        raise datos_invalidos(f"mensaje no puede tener más de {MENSAJE_MAX} caracteres")
    return mensaje


@solo("GET")
def health(request):
    """GET /api/asistente/health/ (docs/api.md, "Ruta de salud").

    Responde 200 sin consultar otros servicios ni la base de datos.
    """
    return respuesta_json({"servicio": SERVICIO, "ok": True})


@solo("POST")
def conversar(request):
    """POST /api/asistente/ con {"mensaje": "..."}."""
    mensaje = _leer_mensaje(request.body)

    clasificador = modelo.obtener()
    if clasificador is None:
        raise modelo_no_disponible(modelo.error_carga())
    try:
        return respuesta_json(Asistente(clasificador).responder(mensaje))
    except ErrorApi:
        raise
    except Exception:
        logger.exception("Falló el clasificador de intenciones")
        raise modelo_no_disponible("El clasificador no pudo procesar el mensaje")
