"""Vistas de recomendar (docs/api.md, sección "Recomendar").

Las vistas solo leen la petición y arman la respuesta. El modelo ya está cargado desde el
inicio del servicio (modelo.py) y la decisión final la toman las reglas (reglas.py).
"""
import logging

from . import modelo
from .errores import ErrorApi, modelo_no_disponible, respuesta_error, respuesta_json
from .errores import ruta_no_encontrada
from .recomendacion import recomendar as decidir
from .validacion import leer_json, validar_envio

SERVICIO = "recomendar"

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


@solo("GET")
def health(request):
    """GET /api/recomendar/health/ (docs/api.md, "Ruta de salud").

    Responde 200 sin consultar otros servicios ni la base de datos.
    """
    return respuesta_json({"servicio": SERVICIO, "ok": True})


@solo("POST")
def recomendar(request):
    """POST /api/recomendar/ con peso_kg, distancia_km, urgente y dimensiones_cm."""
    envio = validar_envio(leer_json(request.body))

    recomendador = modelo.obtener()
    if recomendador is None:
        raise modelo_no_disponible(modelo.error_carga())
    try:
        probabilidades = recomendador.probabilidades(envio)
    except Exception:
        logger.exception("Falló la predicción del modelo")
        raise modelo_no_disponible("El modelo no pudo procesar la solicitud")

    return respuesta_json(decidir(envio, probabilidades))
