"""Vistas de pedidos (docs/api.md, sección "Pedidos").

Las vistas solo leen la petición y arman la respuesta. El registro lo coordina
ConfirmacionPedido (Facade) y los datos los da PedidoRepositorio (Repository).
"""
from . import estados
from .confirmacion import ConfirmacionPedido
from .errores import ErrorApi, datos_invalidos, respuesta_error, respuesta_json
from .errores import ruta_no_encontrada
from .folio import normalizar_folio
from .repositorio import PedidoRepositorio
from .validacion import leer_json

SERVICIO = "pedidos"


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


def _folio_valido(texto):
    folio = normalizar_folio(texto)
    if folio is None:
        raise datos_invalidos("El folio debe tener el formato PQ-AAAAMMDD-XXXX")
    return folio


@solo("GET")
def health(request):
    """GET /api/pedidos/health/ (docs/api.md, "Ruta de salud").

    Responde 200 sin consultar otros servicios ni la base de datos.
    """
    return respuesta_json({"servicio": SERVICIO, "ok": True})


@solo("POST")
def registrar(request):
    """POST /api/pedidos/ con el encabezado Idempotency-Key."""
    pedido, status = ConfirmacionPedido().confirmar(
        request.headers.get("Idempotency-Key"), request.body
    )
    return respuesta_json(pedido, status=status)


@solo("GET")
def consultar(request, folio):
    """GET /api/pedidos/<folio>/ — solo datos mínimos para rastrear."""
    folio = _folio_valido(folio)
    pedido = PedidoRepositorio().obtener(folio)
    if pedido is None:
        return respuesta_error("no_encontrado", f"No existe el pedido con folio {folio}", 404)
    return respuesta_json(pedido)


@solo("PATCH")
def cambiar_estado(request, folio):
    """PATCH /api/pedidos/<folio>/estado/ con {"estado": "..."}."""
    folio = _folio_valido(folio)
    nuevo = leer_json(request.body).get("estado")
    if nuevo not in estados.ESTADOS:
        raise datos_invalidos(
            f"estado es obligatorio y debe ser uno de: {', '.join(estados.ESTADOS)}"
        )
    return respuesta_json(PedidoRepositorio().cambiar_estado(folio, nuevo))
