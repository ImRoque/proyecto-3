"""Validación de la solicitud de recomendación (docs/api.md, "Obtener recomendación")."""
import json
import math
from dataclasses import dataclass

from .errores import datos_invalidos

DIMENSIONES = ("largo", "ancho", "alto")


@dataclass(frozen=True)
class Envio:
    """Datos del envío ya validados."""

    peso_kg: float
    distancia_km: float
    urgente: bool
    largo_cm: float
    ancho_cm: float
    alto_cm: float

    @property
    def lado_max_cm(self):
        return max(self.largo_cm, self.ancho_cm, self.alto_cm)

    def como_features(self):
        """Valores por nombre de feature, como los usa el modelo."""
        return {
            "peso_kg": self.peso_kg,
            "distancia_km": self.distancia_km,
            "urgente": 1 if self.urgente else 0,
            "largo_cm": self.largo_cm,
            "ancho_cm": self.ancho_cm,
            "alto_cm": self.alto_cm,
        }


def leer_json(cuerpo):
    """Convierte el cuerpo en un objeto JSON o lanza datos_invalidos."""
    try:
        datos = json.loads(cuerpo.decode("utf-8"))
    except (UnicodeDecodeError, ValueError):
        raise datos_invalidos("El cuerpo no es JSON válido")
    if not isinstance(datos, dict):
        raise datos_invalidos("El cuerpo debe ser un objeto JSON")
    return datos


def _obligatorio(datos, campo, nombre=None):
    nombre = nombre or campo
    if campo not in datos or datos[campo] is None:
        raise datos_invalidos(f"Falta el campo {nombre}")
    return datos[campo]


def _positivo(datos, campo, nombre=None):
    nombre = nombre or campo
    valor = _obligatorio(datos, campo, nombre)
    # bool es subclase de int en Python: true/false no cuentan como número.
    if isinstance(valor, bool) or not isinstance(valor, (int, float)) or not math.isfinite(valor):
        raise datos_invalidos(f"{nombre} debe ser un número")
    if valor <= 0:
        raise datos_invalidos(f"{nombre} debe ser mayor que 0")
    return float(valor)


def validar_envio(datos):
    """Devuelve un Envio o lanza datos_invalidos con el primer problema encontrado."""
    peso = _positivo(datos, "peso_kg")
    distancia = _positivo(datos, "distancia_km")

    urgente = _obligatorio(datos, "urgente")
    if not isinstance(urgente, bool):
        raise datos_invalidos("urgente debe ser true o false")

    dimensiones = _obligatorio(datos, "dimensiones_cm")
    if not isinstance(dimensiones, dict):
        raise datos_invalidos("dimensiones_cm debe ser un objeto con largo, ancho y alto")
    largo, ancho, alto = (
        _positivo(dimensiones, medida, f"dimensiones_cm.{medida}") for medida in DIMENSIONES
    )

    return Envio(peso, distancia, urgente, largo, ancho, alto)
