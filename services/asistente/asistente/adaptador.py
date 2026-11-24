"""Adapter: convierte el JSON de pedidos y de recomendar en texto para el chat.

Los servicios responden con claves y estados pensados para programas ("EN_CAMINO",
"mismo_dia", "medio_final"). El chat necesita frases para una persona. Esta clase es el
único lugar que conoce la forma de esos JSON; si un contrato cambia, solo cambia aquí.
"""

NOMBRE_MEDIO = {
    "camioneta": "camioneta",
    "motocicleta": "motocicleta",
    "bicicleta": "bicicleta",
    "dron": "dron",
}
NOMBRE_TIPO_SERVICIO = {
    "estandar": "estándar",
    "express": "express",
    "mismo_dia": "mismo día",
}
FRASE_ESTADO = {
    "CREADO": "está registrado y todavía no sale",
    "EN_CAMINO": "va en camino",
    "ENTREGADO": "ya fue entregado",
    "CANCELADO": "fue cancelado",
}


def _medio(clave):
    return NOMBRE_MEDIO.get(clave, clave)


class AdaptadorChat:

    def pedido(self, datos):
        """JSON de GET /api/pedidos/<folio>/ -> texto."""
        folio = datos.get("folio", "")
        estado = datos.get("estado", "")
        frase = FRASE_ESTADO.get(estado, f"está en estado {estado}")
        texto = f"Tu pedido {folio} {frase} ({estado})."
        if datos.get("medio"):
            tipo = NOMBRE_TIPO_SERVICIO.get(datos.get("tipo_servicio"), datos.get("tipo_servicio"))
            texto += f" Va en {_medio(datos['medio'])}"
            texto += f", servicio {tipo}." if tipo else "."
        if datos.get("fecha_limite") and estado not in ("ENTREGADO", "CANCELADO"):
            texto += f" Fecha límite: {datos['fecha_limite']}."
        return texto

    def recomendacion(self, datos, medidas_supuestas=None):
        """JSON de POST /api/recomendar/ -> texto. Usa el `motivo` tal como llega."""
        texto = f"Te recomiendo enviarlo en {_medio(datos.get('medio_final', ''))}."
        if datos.get("motivo"):
            texto += f" {datos['motivo']}"
        alternativas = [_medio(a.get("medio", "")) for a in datos.get("alternativas", [])]
        if alternativas:
            texto += f" Otras opciones: {', '.join(alternativas)}."
        if medidas_supuestas:
            m = medidas_supuestas
            texto += (f" Supuse una caja chica de {m['largo']:g}×{m['ancho']:g}×{m['alto']:g} cm;"
                      " si es más grande, dime las medidas (por ejemplo 40x30x20 cm).")
        return texto

    def recomendacion_rechazada(self, codigo, detalle):
        """Error 400 de POST /api/recomendar/ -> texto."""
        if codigo == "sin_medio_apto":
            return f"Ningún medio puede llevar ese paquete. {detalle}".strip()
        return ("No pude calcular la recomendación con esos datos. Revisa el peso, la "
                "distancia y las medidas.")
