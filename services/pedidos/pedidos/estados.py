"""Estados del pedido y transiciones válidas (docs/api.md, sección "Pedidos")."""

CREADO = "CREADO"
EN_CAMINO = "EN_CAMINO"
ENTREGADO = "ENTREGADO"
CANCELADO = "CANCELADO"

ESTADOS = (CREADO, EN_CAMINO, ENTREGADO, CANCELADO)

TRANSICIONES = {
    CREADO: {EN_CAMINO, CANCELADO},
    EN_CAMINO: {ENTREGADO},
    ENTREGADO: set(),
    CANCELADO: set(),
}


def transicion_valida(actual, nuevo):
    """True si el pedido puede pasar de `actual` a `nuevo`. Repetir el estado no es válido."""
    return nuevo in TRANSICIONES.get(actual, set())
