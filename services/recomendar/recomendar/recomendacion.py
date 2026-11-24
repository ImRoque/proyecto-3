"""Decide el medio final a partir de las probabilidades del modelo y las reglas de negocio.

docs/api.md, "Cómo se decide el medio_final":
1. Si el medio del modelo cumple todas las reglas, es el final (corregido_por_reglas false).
2. Si no, el final es el medio apto con mayor probabilidad del modelo (corregido true).
3. Si ningún medio es apto, error 400 sin_medio_apto.
"""
from .errores import ErrorApi
from .reglas import MEDIOS, REGLAS, primera_regla_que_descarta

DECIMALES_CONFIANZA = 4


def recomendar(envio, probabilidades, reglas=REGLAS):
    """Arma la respuesta del contrato. `probabilidades` es {medio: probabilidad}."""
    # Orden por probabilidad (mayor primero); a igual probabilidad, el orden de MEDIOS.
    ordenados = sorted(MEDIOS, key=lambda m: (-probabilidades.get(m, 0.0), MEDIOS.index(m)))
    medio_modelo = ordenados[0]

    aptos = []
    descartes = {}
    for medio in ordenados:
        regla, motivo = primera_regla_que_descarta(envio, medio, reglas)
        if regla is None:
            aptos.append(medio)
        else:
            descartes[medio] = (regla, motivo)

    if not aptos:
        raise ErrorApi(
            "sin_medio_apto",
            "Ningún medio cumple las reglas de negocio: "
            + "; ".join(motivo for _, motivo in descartes.values()),
            400,
        )

    medio_final = aptos[0]
    corregido = medio_final != medio_modelo
    if corregido:
        regla, motivo_regla = descartes[medio_modelo]
        motivo = (f"{motivo_regla} [{regla.codigo}. {regla.nombre}]; "
                  f"se eligió {medio_final}, el siguiente medio apto según el modelo.")
    else:
        motivo = f"El modelo propuso {medio_modelo} y cumple todas las reglas de negocio."

    return {
        "medio_modelo": medio_modelo,
        "confianza": round(probabilidades.get(medio_modelo, 0.0), DECIMALES_CONFIANZA),
        "medio_final": medio_final,
        "corregido_por_reglas": corregido,
        "motivo": motivo,
        "alternativas": [
            {"medio": m, "confianza": round(probabilidades.get(m, 0.0), DECIMALES_CONFIANZA)}
            for m in aptos[1:]
        ],
    }
