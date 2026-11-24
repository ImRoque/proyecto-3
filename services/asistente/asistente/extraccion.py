"""Extracción de datos del mensaje: folio, peso, distancia, medidas y urgencia.

Solo reconoce números escritos con cifras ("3 kg", "1.5 kilos", "800 gramos"); no entiende
números con letra ("tres kilos").
"""
import re

# Folio de docs/api.md: PQ-AAAAMMDD-XXXX, con XXXX de A-Z y 2-9 sin O, I, 0 ni 1.
_FOLIO = re.compile(r"\bPQ-\d{8}-[A-HJ-NP-Z2-9]{4}\b", re.IGNORECASE)

_NUMERO = r"(\d+(?:[.,]\d+)?)"
_KM = re.compile(_NUMERO + r"\s*(?:km|kms|kil[oó]metros?)\b", re.IGNORECASE)
_METROS = re.compile(_NUMERO + r"\s*(?:metros?|mts?)\b", re.IGNORECASE)
_KG = re.compile(_NUMERO + r"\s*(?:kg|kgs|kilos?|kilogramos?)\b", re.IGNORECASE)
_GRAMOS = re.compile(_NUMERO + r"\s*(?:g|gr|grs|gramos?)\b", re.IGNORECASE)
_MEDIDAS = re.compile(
    _NUMERO + r"\s*[x×*]\s*" + _NUMERO + r"\s*[x×*]\s*" + _NUMERO + r"\s*(?:cm)?",
    re.IGNORECASE,
)
_URGENTE = re.compile(r"\b(?:urgente|urge|cuanto antes|lo antes posible)\b", re.IGNORECASE)
_NO_URGENTE = re.compile(r"\bno\s+(?:es\s+|está\s+|esta\s+)?(?:urgente|urge)\b",
                         re.IGNORECASE)


def _numero(texto):
    return float(texto.replace(",", "."))


def _primero_positivo(patron, mensaje, factor=1.0):
    for coincidencia in patron.finditer(mensaje):
        valor = _numero(coincidencia.group(1))
        if valor > 0:
            return round(valor * factor, 3)
    return None


def extraer_folio(mensaje):
    """Folio en mayúsculas, o None si el mensaje no trae uno válido."""
    coincidencia = _FOLIO.search(mensaje)
    return coincidencia.group(0).upper() if coincidencia else None


def extraer_peso_kg(mensaje):
    """Peso en kg ("3 kg", "1,5 kilos", "800 gramos"), o None."""
    peso = _primero_positivo(_KG, mensaje)
    if peso is None:
        peso = _primero_positivo(_GRAMOS, mensaje, factor=0.001)
    return peso


def extraer_distancia_km(mensaje):
    """Distancia en km ("5 km", "12 kilómetros", "800 metros"), o None."""
    distancia = _primero_positivo(_KM, mensaje)
    if distancia is None:
        distancia = _primero_positivo(_METROS, mensaje, factor=0.001)
    return distancia


def extraer_dimensiones_cm(mensaje):
    """{"largo", "ancho", "alto"} de "30x20x15 cm", o None si no vienen las tres."""
    for coincidencia in _MEDIDAS.finditer(mensaje):
        medidas = [_numero(g) for g in coincidencia.groups()]
        if all(m > 0 for m in medidas):
            return dict(zip(("largo", "ancho", "alto"), medidas))
    return None


def extraer_urgente(mensaje):
    """True si el mensaje pide urgencia; False si no la menciona o la niega."""
    if _NO_URGENTE.search(mensaje):
        return False
    return bool(_URGENTE.search(mensaje))
