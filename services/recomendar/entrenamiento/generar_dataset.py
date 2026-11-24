"""Genera datasets/envios.csv de forma reproducible (semilla fija).

Cada fila es un envío sintético con la etiqueta del medio que se considera adecuado.
La etiqueta sale de reglas razonables del dominio más un poco de ruido, para que el
modelo tenga algo que aprender sin que el dataset sea una copia exacta de las reglas.

Uso, desde services/recomendar/:

    python -m entrenamiento.generar_dataset
    python -m entrenamiento.generar_dataset --n 3000 --semilla 42

Solo usa la biblioteca estándar, así el resultado no depende de versiones de numpy.
"""

import argparse
import csv
import math
import random
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
RUTA_CSV = RAIZ / "datasets" / "envios.csv"

COLUMNAS = ["peso_kg", "distancia_km", "urgente", "largo_cm", "ancho_cm", "alto_cm", "medio"]
MEDIOS = ["camioneta", "motocicleta", "bicicleta", "dron"]

# Límites por medio: (peso máximo kg, distancia máxima km, lado más largo cm).
# Coinciden con R1, R2 y R3 de docs/api.md y con el catálogo.
LIMITES = {
    "dron": (2, 10, 40),
    "bicicleta": (8, 8, 50),
    "motocicleta": (20, 40, 60),
    "camioneta": (1000, 300, 200),
}

# R4: si es urgente y la distancia supera este valor, la bicicleta no aplica.
DISTANCIA_URGENTE_BICICLETA = 3

# Distancia a partir de la cual se prefiere el dron sobre la bicicleta en envíos ligeros.
# Se mueve un poco en cada fila para que la frontera no sea exacta.
DISTANCIA_PREFIERE_DRON = 3
RUIDO_UMBRAL_DRON = 0.5

# Probabilidad de que la etiqueta se cambie por otro medio que también es apto.
PROBABILIDAD_RUIDO_ETIQUETA = 0.05

N_POR_DEFECTO = 3000
SEMILLA_POR_DEFECTO = 42


def medios_aptos(peso_kg, distancia_km, urgente, lado_max_cm):
    """Medios que pueden hacer el envío según las reglas R1 a R4."""
    aptos = []
    for medio in MEDIOS:
        peso_max, distancia_max, lado_max = LIMITES[medio]
        if peso_kg > peso_max or distancia_km > distancia_max or lado_max_cm > lado_max:
            continue
        if medio == "bicicleta" and urgente and distancia_km > DISTANCIA_URGENTE_BICICLETA:
            continue
        aptos.append(medio)
    return aptos


def etiqueta_ideal(peso_kg, distancia_km, urgente, lado_max_cm,
                   umbral_dron=DISTANCIA_PREFIERE_DRON):
    """Medio preferido entre los aptos, sin ruido.

    1. Dron, si es apto y el envío es urgente o va más lejos que el umbral.
    2. Bicicleta, si es apta (la más barata para envíos cortos).
    3. Motocicleta, si es apta.
    4. Camioneta en cualquier otro caso.
    """
    aptos = medios_aptos(peso_kg, distancia_km, urgente, lado_max_cm)
    if "dron" in aptos and (urgente or distancia_km > umbral_dron):
        return "dron"
    for medio in ("bicicleta", "motocicleta", "dron"):
        if medio in aptos:
            return medio
    return "camioneta"


def _log_uniforme(rng, minimo, maximo):
    return math.exp(rng.uniform(math.log(minimo), math.log(maximo)))


def _muestrear_peso(rng):
    # Rangos un poco más allá de los límites para que el modelo vea las fronteras.
    rangos = [(0.1, 2.5), (2.5, 8.5), (8.5, 22.0), (22.0, 800.0)]
    minimo, maximo = rng.choices(rangos, weights=[0.35, 0.30, 0.20, 0.15])[0]
    if maximo > 100:
        return _log_uniforme(rng, minimo, maximo)
    return rng.uniform(minimo, maximo)


def _muestrear_distancia(rng):
    rangos = [(0.3, 10.5), (10.5, 42.0), (42.0, 250.0)]
    minimo, maximo = rng.choices(rangos, weights=[0.45, 0.35, 0.20])[0]
    if maximo > 100:
        return _log_uniforme(rng, minimo, maximo)
    return rng.uniform(minimo, maximo)


def _muestrear_dimensiones(rng, peso_kg):
    # El tamaño crece con la raíz cúbica del peso, con variación de forma.
    base = 12 * peso_kg ** (1 / 3) * rng.uniform(0.7, 1.5)
    largo = base * rng.uniform(1.0, 1.8)
    ancho = base * rng.uniform(0.6, 1.0)
    alto = base * rng.uniform(0.3, 0.9)
    return [round(min(max(medida, 2.0), 190.0), 1) for medida in (largo, ancho, alto)]


def generar(n=N_POR_DEFECTO, semilla=SEMILLA_POR_DEFECTO):
    """Devuelve una lista de filas (dict) con las columnas de COLUMNAS."""
    rng = random.Random(semilla)
    filas = []
    for _ in range(n):
        peso = round(_muestrear_peso(rng), 2)
        distancia = round(_muestrear_distancia(rng), 2)
        urgente = rng.random() < 0.3
        largo, ancho, alto = _muestrear_dimensiones(rng, peso)
        lado_max = max(largo, ancho, alto)

        umbral = DISTANCIA_PREFIERE_DRON + rng.gauss(0, RUIDO_UMBRAL_DRON)
        medio = etiqueta_ideal(peso, distancia, urgente, lado_max, umbral_dron=umbral)

        if rng.random() < PROBABILIDAD_RUIDO_ETIQUETA:
            otros = [m for m in medios_aptos(peso, distancia, urgente, lado_max) if m != medio]
            if otros:
                medio = rng.choice(otros)

        filas.append({
            "peso_kg": peso,
            "distancia_km": distancia,
            "urgente": int(urgente),
            "largo_cm": largo,
            "ancho_cm": ancho,
            "alto_cm": alto,
            "medio": medio,
        })
    return filas


def escribir_csv(filas, ruta):
    ruta = Path(ruta)
    ruta.parent.mkdir(parents=True, exist_ok=True)
    with ruta.open("w", newline="", encoding="utf-8") as archivo:
        escritor = csv.DictWriter(archivo, fieldnames=COLUMNAS, lineterminator="\n")
        escritor.writeheader()
        escritor.writerows(filas)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Genera el dataset de envíos.")
    parser.add_argument("--n", type=int, default=N_POR_DEFECTO, help="Número de filas")
    parser.add_argument("--semilla", type=int, default=SEMILLA_POR_DEFECTO)
    parser.add_argument("--salida", type=Path, default=RUTA_CSV)
    args = parser.parse_args(argv)

    filas = generar(args.n, args.semilla)
    escribir_csv(filas, args.salida)

    conteo = {medio: 0 for medio in MEDIOS}
    for fila in filas:
        conteo[fila["medio"]] += 1
    print(f"Escribí {len(filas)} filas en {args.salida}")
    for medio in MEDIOS:
        print(f"  {medio:<12} {conteo[medio]:>5}")


if __name__ == "__main__":
    main()
