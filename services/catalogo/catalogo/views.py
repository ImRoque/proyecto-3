from django.http import JsonResponse

SERVICIO = "catalogo"


def health(request):
    """GET /api/catalogo/health/ (docs/api.md, "Ruta de salud").

    Responde 200 sin consultar otros servicios ni la base de datos.
    """
    return JsonResponse(
        {"servicio": SERVICIO, "ok": True},
        content_type="application/json; charset=utf-8",
    )
