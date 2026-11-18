"""Vistas del catálogo (docs/api.md, sección "Catálogo").

Las vistas validan la petición y arman la respuesta; los datos los piden al repositorio.
"""
from .errores import respuesta_error, respuesta_json, ruta_no_encontrada
from .repositorio import MedioRepositorio, TipoServicioRepositorio

SERVICIO = "catalogo"
Q_MAX_CARACTERES = 100


def solo_get(vista):
    """Solo acepta GET. Otro método responde 404 ruta_no_encontrada.

    El contrato no admite 405, así que una combinación ruta + método que no existe se trata
    como ruta inexistente.
    """
    def envoltura(request, *args, **kwargs):
        if request.method != "GET":
            return ruta_no_encontrada(request)
        return vista(request, *args, **kwargs)

    envoltura.__name__ = vista.__name__
    envoltura.__doc__ = vista.__doc__
    return envoltura


@solo_get
def health(request):
    """GET /api/catalogo/health/ (docs/api.md, "Ruta de salud").

    Responde 200 sin consultar otros servicios ni la base de datos.
    """
    return respuesta_json({"servicio": SERVICIO, "ok": True})


@solo_get
def listar_medios(request):
    """GET /api/catalogo/medios/?q=<texto>"""
    q = request.GET.get("q", "").strip()
    if len(q) > Q_MAX_CARACTERES:
        return respuesta_error(
            "datos_invalidos", f"q no puede tener más de {Q_MAX_CARACTERES} caracteres", 400
        )
    medios = MedioRepositorio().listar(q or None)
    return respuesta_json({"medios": medios, "total": len(medios)})


@solo_get
def detalle_medio(request, clave):
    """GET /api/catalogo/medios/<clave>/"""
    medio = MedioRepositorio().obtener(clave)
    if medio is None:
        return respuesta_error("no_encontrado", f"No existe el medio con clave {clave}", 404)
    return respuesta_json(medio)


@solo_get
def listar_tipos_servicio(request):
    """GET /api/catalogo/tipos-servicio/"""
    tipos = TipoServicioRepositorio().listar()
    return respuesta_json({"tipos_servicio": tipos, "total": len(tipos)})
