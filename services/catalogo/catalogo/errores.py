"""Respuestas de error con el formato único de docs/api.md: {"error", "detalle"}."""
from django.http import JsonResponse

CONTENT_TYPE = "application/json; charset=utf-8"


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
