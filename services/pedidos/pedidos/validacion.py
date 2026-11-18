"""Reglas de validación del registro de pedido (docs/api.md, "Registrar un pedido").

La existencia del medio y del tipo de servicio, y la capacidad del medio, se revisan en la
confirmación porque necesitan al servicio catalogo.
"""
import datetime
import json
import math
import re

from django.utils import timezone

from .errores import ErrorApi, datos_invalidos

TEXTO_MAX = 200
_UUID_V4 = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", re.IGNORECASE
)
_FECHA = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def validar_idempotency_key(valor):
    """Devuelve la clave en minúsculas o lanza falta_idempotency_key."""
    if not valor or not _UUID_V4.match(valor.strip()):
        raise ErrorApi(
            "falta_idempotency_key",
            "El encabezado Idempotency-Key es obligatorio y debe ser un UUID v4",
            400,
        )
    return valor.strip().lower()


def leer_json(cuerpo):
    """Convierte el cuerpo en un objeto JSON o lanza datos_invalidos."""
    try:
        datos = json.loads(cuerpo.decode("utf-8"))
    except (UnicodeDecodeError, ValueError):
        raise datos_invalidos("El cuerpo no es JSON válido")
    if not isinstance(datos, dict):
        raise datos_invalidos("El cuerpo debe ser un objeto JSON")
    return datos


def _obligatorio(datos, campo):
    if campo not in datos or datos[campo] is None:
        raise datos_invalidos(f"Falta el campo {campo}")
    return datos[campo]


def _texto(datos, campo):
    valor = _obligatorio(datos, campo)
    if not isinstance(valor, str) or not valor.strip():
        raise datos_invalidos(f"{campo} debe ser un texto no vacío")
    valor = valor.strip()
    if len(valor) > TEXTO_MAX:
        raise datos_invalidos(f"{campo} no puede tener más de {TEXTO_MAX} caracteres")
    return valor


def _positivo(valor, campo):
    # bool es subclase de int en Python: true no debe pasar como número.
    es_numero = isinstance(valor, (int, float)) and not isinstance(valor, bool)
    if not es_numero or not math.isfinite(valor) or valor <= 0:
        raise datos_invalidos(f"{campo} debe ser un número mayor que 0")
    return float(valor)


def _booleano(datos, campo):
    valor = _obligatorio(datos, campo)
    if not isinstance(valor, bool):
        raise datos_invalidos(f"{campo} debe ser true o false")
    return valor


def _fecha_limite(datos):
    valor = _obligatorio(datos, "fecha_limite")
    try:
        if not isinstance(valor, str) or not _FECHA.match(valor):
            raise ValueError
        fecha = datetime.date.fromisoformat(valor)
    except ValueError:
        raise datos_invalidos("fecha_limite debe ser una fecha con formato AAAA-MM-DD")
    if fecha < timezone.localdate():
        raise datos_invalidos("fecha_limite no puede ser anterior a hoy")
    return fecha


def validar_pedido(datos):
    """Valida el cuerpo del registro y devuelve los datos limpios."""
    dimensiones = _obligatorio(datos, "dimensiones_cm")
    if not isinstance(dimensiones, dict):
        raise datos_invalidos("dimensiones_cm debe ser un objeto con largo, ancho y alto")

    return {
        "origen": _texto(datos, "origen"),
        "destino": _texto(datos, "destino"),
        "distancia_km": _positivo(_obligatorio(datos, "distancia_km"), "distancia_km"),
        "peso_kg": _positivo(_obligatorio(datos, "peso_kg"), "peso_kg"),
        "dimensiones_cm": {
            medida: _positivo(
                _obligatorio(dimensiones, medida), f"dimensiones_cm.{medida}"
            )
            for medida in ("largo", "ancho", "alto")
        },
        "urgente": _booleano(datos, "urgente"),
        "seguro": _booleano(datos, "seguro"),
        "fecha_limite": _fecha_limite(datos),
        "medio": _texto(datos, "medio"),
        "tipo_servicio": _texto(datos, "tipo_servicio"),
    }
