"""Reglas de negocio que pueden corregir al modelo (docs/api.md, "Reglas de negocio propuestas").

Patrón Strategy: cada regla es una clase con la misma interfaz, `descarta(envio, medio)`,
que devuelve el motivo si el medio no puede hacer el envío o None si la regla no lo descarta.
El recomendador recorre REGLAS en orden sin saber qué revisa cada una; agregar o quitar una
regla no cambia el resto del código.
"""

MEDIOS = ("camioneta", "motocicleta", "bicicleta", "dron")

# Límites por medio. Deben coincidir con peso_max_kg y distancia_max_km del catálogo.
PESO_MAX_KG = {"dron": 2, "bicicleta": 8, "motocicleta": 20, "camioneta": 1000}
DISTANCIA_MAX_KM = {"dron": 10, "bicicleta": 8, "motocicleta": 40, "camioneta": 300}
LADO_MAX_CM = {"dron": 40, "bicicleta": 50, "motocicleta": 60, "camioneta": 200}
DISTANCIA_URGENTE_BICICLETA_KM = 3


CON_ARTICULO = {
    "camioneta": "La camioneta",
    "motocicleta": "La motocicleta",
    "bicicleta": "La bicicleta",
    "dron": "El dron",
}


def _numero(valor):
    """3.0 -> "3", 3.5 -> "3.5" para los mensajes."""
    return f"{valor:g}"


class Regla:
    """Interfaz común de las reglas."""

    codigo = ""
    nombre = ""

    def descarta(self, envio, medio):
        """Motivo (texto) si `medio` no puede hacer `envio`; None si esta regla lo permite."""
        raise NotImplementedError


class ReglaPesoMaximo(Regla):
    codigo = "R1"
    nombre = "Peso máximo"

    def descarta(self, envio, medio):
        limite = PESO_MAX_KG[medio]
        if envio.peso_kg > limite:
            return (f"{CON_ARTICULO[medio]} no lleva más de {_numero(limite)} kg "
                    f"(el paquete pesa {_numero(envio.peso_kg)} kg)")
        return None


class ReglaDistanciaMaxima(Regla):
    codigo = "R2"
    nombre = "Distancia máxima"

    def descarta(self, envio, medio):
        limite = DISTANCIA_MAX_KM[medio]
        if envio.distancia_km > limite:
            return (f"{CON_ARTICULO[medio]} no recorre más de {_numero(limite)} km "
                    f"(el envío es de {_numero(envio.distancia_km)} km)")
        return None


class ReglaTamanoPaquete(Regla):
    codigo = "R3"
    nombre = "Tamaño del paquete"

    def descarta(self, envio, medio):
        limite = LADO_MAX_CM[medio]
        if envio.lado_max_cm > limite:
            return (f"{CON_ARTICULO[medio]} no lleva paquetes con un lado de más de "
                    f"{_numero(limite)} cm "
                    f"(el lado más largo mide {_numero(envio.lado_max_cm)} cm)")
        return None


class ReglaUrgencia(Regla):
    codigo = "R4"
    nombre = "Urgencia"

    def descarta(self, envio, medio):
        if (medio == "bicicleta" and envio.urgente
                and envio.distancia_km > DISTANCIA_URGENTE_BICICLETA_KM):
            return (f"Un envío urgente de más de {_numero(DISTANCIA_URGENTE_BICICLETA_KM)} km "
                    f"no va en bicicleta")
        return None


# Orden en que se aplican. Para cada medio gana la primera regla que lo descarta.
REGLAS = (ReglaPesoMaximo(), ReglaDistanciaMaxima(), ReglaTamanoPaquete(), ReglaUrgencia())


def primera_regla_que_descarta(envio, medio, reglas=REGLAS):
    """Devuelve (regla, motivo) de la primera regla que descarta el medio, o (None, None)."""
    for regla in reglas:
        motivo = regla.descarta(envio, medio)
        if motivo:
            return regla, motivo
    return None, None
