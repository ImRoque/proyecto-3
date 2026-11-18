"""Confirmación de un pedido nuevo (patrón Facade).

La vista de registro solo llama a ConfirmacionPedido.confirmar(). Esta clase coordina los
pasos que la vista no debe conocer: validar, revisar la Idempotency-Key, consultar el
catálogo, calcular el costo y guardar.
"""
import hashlib
import json
from decimal import ROUND_HALF_UP, Decimal

from .cliente_catalogo import CatalogoNoDisponible, ClienteCatalogo
from .errores import ErrorApi, datos_invalidos
from .repositorio import ClaveYaRegistrada, PedidoRepositorio
from .validacion import leer_json, validar_idempotency_key, validar_pedido

RECARGO_SEGURO = Decimal("0.10")
CENTAVOS = Decimal("0.01")


def calcular_costo(medio, tipo_servicio, distancia_km, seguro):
    """costo = (costo_base + costo_por_km * distancia_km) * multiplicador_costo,
    más 10 % si hay seguro. Redondeado a 2 decimales (docs/api.md, "Cálculo del costo").
    """
    def dec(valor):
        return Decimal(str(valor))

    subtotal = (
        dec(medio["costo_base"]) + dec(medio["costo_por_km"]) * dec(distancia_km)
    ) * dec(tipo_servicio["multiplicador_costo"])
    if seguro:
        subtotal += subtotal * RECARGO_SEGURO
    return subtotal.quantize(CENTAVOS, rounding=ROUND_HALF_UP)


def huella(datos):
    """SHA-256 del cuerpo validado. El orden de los campos no cambia la huella."""
    normalizado = json.dumps(datos, sort_keys=True, default=str, separators=(",", ":"))
    return hashlib.sha256(normalizado.encode("utf-8")).hexdigest()


class ConfirmacionPedido:

    def __init__(self, repositorio=None, catalogo=None):
        self.repositorio = repositorio or PedidoRepositorio()
        self.catalogo = catalogo or ClienteCatalogo()

    def confirmar(self, idempotency_key, cuerpo):
        """Registra el pedido y devuelve (datos del pedido, código HTTP).

        201 si se creó; 200 si la clave ya se había usado con el mismo cuerpo.
        Lanza ErrorApi con el error del contrato en cualquier otro caso.
        """
        clave = validar_idempotency_key(idempotency_key)
        datos = validar_pedido(leer_json(cuerpo))
        huella_cuerpo = huella(datos)

        # Camino rápido: el cliente reintentó o hizo doble clic.
        existente = self.repositorio.buscar_por_clave(clave)
        if existente is not None:
            return self._repetido(existente, huella_cuerpo)

        medio, tipo = self._consultar_catalogo(datos)
        costo = calcular_costo(medio, tipo, datos["distancia_km"], datos["seguro"])

        try:
            pedido = self.repositorio.crear(datos, costo, clave, huella_cuerpo)
        except ClaveYaRegistrada:
            # Otra petición con la misma clave ganó la carrera: se responde con su pedido.
            return self._repetido(self.repositorio.buscar_por_clave(clave), huella_cuerpo)
        return pedido, 201

    @staticmethod
    def _repetido(existente, huella_cuerpo):
        huella_guardada, pedido = existente
        if huella_guardada != huella_cuerpo:
            raise ErrorApi(
                "idempotency_key_reutilizada",
                "La Idempotency-Key ya se usó con un cuerpo distinto",
                409,
            )
        return pedido, 200

    def _consultar_catalogo(self, datos):
        try:
            medio = self.catalogo.obtener_medio(datos["medio"])
            tipo = self.catalogo.obtener_tipo_servicio(datos["tipo_servicio"])
        except CatalogoNoDisponible:
            raise ErrorApi(
                "servicio_no_disponible", "El servicio catalogo no respondió", 503
            )
        if medio is None:
            raise datos_invalidos(f"No existe el medio {datos['medio']}")
        if tipo is None:
            raise datos_invalidos(f"No existe el tipo de servicio {datos['tipo_servicio']}")

        if datos["peso_kg"] > medio["peso_max_kg"]:
            raise ErrorApi(
                "medio_no_apto",
                f"{medio['clave']} lleva máximo {medio['peso_max_kg']} kg",
                400,
            )
        if datos["distancia_km"] > medio["distancia_max_km"]:
            raise ErrorApi(
                "medio_no_apto",
                f"{medio['clave']} recorre máximo {medio['distancia_max_km']} km",
                400,
            )
        return medio, tipo
