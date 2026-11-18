"""Folio del pedido: PQ-AAAAMMDD-XXXX (docs/api.md, "Convenciones generales")."""
import re
import secrets

# A-Z y 2-9 sin O, I, 0 ni 1 para que no se confundan al leerlos.
ALFABETO = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
LONGITUD_SUFIJO = 4

_PATRON = re.compile(r"^PQ-\d{8}-[A-HJ-NP-Z2-9]{4}$")


def generar_folio(fecha):
    """Genera un folio para la fecha de creación dada. La unicidad la garantiza la base."""
    sufijo = "".join(secrets.choice(ALFABETO) for _ in range(LONGITUD_SUFIJO))
    return f"PQ-{fecha:%Y%m%d}-{sufijo}"


def normalizar_folio(texto):
    """Devuelve el folio en mayúsculas, o None si no cumple el formato."""
    folio = texto.strip().upper()
    return folio if _PATRON.match(folio) else None
