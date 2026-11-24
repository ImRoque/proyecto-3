"""Entrena el recomendador con datasets/envios.csv y lo guarda en modelos/recomendador.joblib.

Se ejecuta aparte, nunca dentro de una petición HTTP. Uso, desde services/recomendar/:

    python -m entrenamiento.entrenar

El archivo .joblib guarda un diccionario con el modelo y los datos que necesita quien lo
cargue: el orden de las features, las clases y la versión de scikit-learn usada.
"""

import argparse
import csv
from pathlib import Path

import joblib
import numpy as np
import sklearn
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.model_selection import train_test_split

RAIZ = Path(__file__).resolve().parent.parent
RUTA_CSV = RAIZ / "datasets" / "envios.csv"
RUTA_MODELO = RAIZ / "modelos" / "recomendador.joblib"

FEATURES = ["peso_kg", "distancia_km", "urgente", "largo_cm", "ancho_cm", "alto_cm"]
ETIQUETA = "medio"
CLASES = ["camioneta", "motocicleta", "bicicleta", "dron"]

PROPORCION_PRUEBA = 0.2
SEMILLA = 42


def cargar_dataset(ruta):
    """Lee el CSV y devuelve (X, y) como arreglos de numpy."""
    with Path(ruta).open(newline="", encoding="utf-8") as archivo:
        lector = csv.DictReader(archivo)
        faltantes = [c for c in FEATURES + [ETIQUETA] if c not in (lector.fieldnames or [])]
        if faltantes:
            raise ValueError(f"Al CSV le faltan columnas: {', '.join(faltantes)}")
        filas = list(lector)
    if not filas:
        raise ValueError("El CSV no tiene filas")

    X = np.array([[float(fila[c]) for c in FEATURES] for fila in filas])
    y = np.array([fila[ETIQUETA] for fila in filas])
    desconocidas = sorted(set(y) - set(CLASES))
    if desconocidas:
        raise ValueError(f"Etiquetas desconocidas en el CSV: {', '.join(desconocidas)}")
    return X, y


def entrenar(X, y, semilla=SEMILLA, proporcion_prueba=PROPORCION_PRUEBA):
    """Separa entrenamiento y prueba, entrena y devuelve (modelo, metricas)."""
    X_ent, X_prueba, y_ent, y_prueba = train_test_split(
        X, y, test_size=proporcion_prueba, random_state=semilla, stratify=y,
    )
    modelo = RandomForestClassifier(
        n_estimators=200, min_samples_leaf=2, random_state=semilla,
    )
    modelo.fit(X_ent, y_ent)

    y_pred = modelo.predict(X_prueba)
    metricas = {
        "accuracy": float(accuracy_score(y_prueba, y_pred)),
        "matriz_confusion": confusion_matrix(y_prueba, y_pred, labels=CLASES).tolist(),
        "reporte": classification_report(
            y_prueba, y_pred, labels=CLASES, digits=3, zero_division=0,
        ),
        "n_entrenamiento": len(y_ent),
        "n_prueba": len(y_prueba),
    }
    return modelo, metricas


def guardar(modelo, metricas, ruta):
    ruta = Path(ruta)
    ruta.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(
        {
            "modelo": modelo,
            "features": FEATURES,
            "clases": [str(clase) for clase in modelo.classes_],
            "sklearn_version": sklearn.__version__,
            "accuracy_prueba": metricas["accuracy"],
        },
        ruta,
        compress=3,
    )


def imprimir_metricas(metricas):
    print(f"Filas de entrenamiento: {metricas['n_entrenamiento']}")
    print(f"Filas de prueba:        {metricas['n_prueba']}")
    print(f"Accuracy (prueba):      {metricas['accuracy']:.4f}")
    print()
    print("Matriz de confusión (filas = real, columnas = predicho):")
    ancho = max(len(c) for c in CLASES) + 2
    print(" " * ancho + "".join(f"{c:>{ancho}}" for c in CLASES))
    for clase, fila in zip(CLASES, metricas["matriz_confusion"]):
        print(f"{clase:<{ancho}}" + "".join(f"{v:>{ancho}}" for v in fila))
    print()
    print(metricas["reporte"])


def main(argv=None):
    parser = argparse.ArgumentParser(description="Entrena el recomendador de medios.")
    parser.add_argument("--csv", type=Path, default=RUTA_CSV)
    parser.add_argument("--salida", type=Path, default=RUTA_MODELO)
    parser.add_argument("--semilla", type=int, default=SEMILLA)
    args = parser.parse_args(argv)

    X, y = cargar_dataset(args.csv)
    modelo, metricas = entrenar(X, y, semilla=args.semilla)
    imprimir_metricas(metricas)
    guardar(modelo, metricas, args.salida)
    print(f"Modelo guardado en {args.salida}")
    return metricas


if __name__ == "__main__":
    main()
