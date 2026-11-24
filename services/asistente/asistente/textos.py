"""Respuestas fijas del asistente (docs/api.md, "Intenciones propuestas").

Solo información que no cambia con cada pedido. Los datos vivos (estado de un pedido,
recomendación) se consultan siempre por API.
"""

SALUDO = (
    "¡Hola! Soy el asistente de paquetería. Puedo rastrear tu pedido con su folio, "
    "recomendarte un medio de envío, darte tarifas de referencia y decirte nuestros horarios. "
    "¿En qué te ayudo?"
)

HORARIOS = (
    "Atendemos de lunes a sábado de 8:00 a 20:00. Las entregas salen de lunes a sábado de "
    "9:00 a 19:00; los domingos y días festivos no hay entregas. El servicio mismo día se "
    "puede pedir hasta las 14:00."
)

# Tarifas de referencia: valores del catálogo inicial (services/catalogo/.../fixtures).
# Si cambian en el catálogo, hay que actualizar este texto.
COTIZAR = (
    "Tarifas de referencia (costo base + costo por km, en MXN): bicicleta $25 + $2/km, "
    "motocicleta $40 + $4.50/km, dron $80 + $6/km y camioneta $120 + $8/km. El servicio "
    "express cuesta 1.5 veces y el mismo día 2 veces la tarifa estándar; el seguro agrega 10 %. "
    "El costo exacto lo calcula el sistema cuando registras el pedido."
)

DESCONOCIDA = (
    "Perdón, no entendí tu mensaje. Puedo ayudarte a rastrear un pedido "
    "(por ejemplo: \"¿cómo va el folio PQ-20261117-7KQ3?\"), recomendarte un medio de envío "
    "(\"¿qué me recomiendas para 3 kg a 5 km?\"), darte tarifas o decirte los horarios."
)

PEDIR_FOLIO = (
    "Con gusto te ayudo a rastrearlo. Escríbeme el folio de tu pedido, tiene el formato "
    "PQ-AAAAMMDD-XXXX (por ejemplo: PQ-20261117-7KQ3)."
)

FOLIO_NO_ENCONTRADO = "No encontré un pedido con el folio {folio}. Revisa que esté bien escrito."

PEDIR_DATOS_RECOMENDAR = (
    "Para recomendarte un medio necesito {faltantes}. Escríbelo en un solo mensaje, por "
    "ejemplo: \"¿qué me recomiendas para 3 kg a 5 km, 30x20x15 cm?\"."
)

PEDIDOS_NO_DISPONIBLE = (
    "En este momento no puedo consultar tu pedido. Intenta de nuevo en unos minutos."
)

RECOMENDAR_NO_DISPONIBLE = (
    "En este momento no puedo calcular una recomendación. Intenta de nuevo en unos minutos."
)
