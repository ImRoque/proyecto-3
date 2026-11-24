"""Errores y respuestas JSON con el formato único de docs/api.md: {"error", "detalle"}."""
from django.http import JsonResponse

CONTENT_TYPE = "application/json; charset=utf-8"


class ErrorApi(Exception):
    """Error que se responde al cliente con el código HTTP y el `error` del contrato."""

    def __init__(self, codigo, detalle, status):
        super().__init__(detalle)
        self.codigo = codigo
        self.detalle = detalle
        self.status = status


def datos_invalidos(detalle):
    return ErrorApi("datos_invalidos", detalle, 400)


def modelo_no_disponible(detalle="El modelo de recomendación no está disponible"):
    return ErrorApi("modelo_no_disponible", detalle, 503)


def respuesta_json(datos, status=200):
    return JsonResponse(
        datos,
        status=status,
        content_type=CONTENT_TYPE,
        json_dumps_params={"ensure_ascii": False},
    )


def respuesta_error(codigo, detalle, status):
    return respuesta_json({"error": codigo, "detalle": detalle}, status=status)


def ruta_no_encontrada(request, exception=None):
    """handler404 de Django: rutas inexistentes también responden en JSON."""
    return respuesta_error("ruta_no_encontrada", "La ruta solicitada no existe", 404)
