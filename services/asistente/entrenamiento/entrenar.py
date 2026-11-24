"""Entrena el clasificador de intenciones y lo guarda en modelos/intenciones.joblib.

Se ejecuta aparte, nunca dentro de una petición HTTP. Uso, desde services/asistente/:

    python -m entrenamiento.entrenar

Lee datasets/intenciones.csv (columnas texto, intencion), separa entrenamiento y prueba de
forma estratificada, entrena TF-IDF + regresión logística e imprime las métricas.

La intención `desconocida` de docs/api.md no se entrena: el servicio la usará cuando la
confianza del clasificador sea baja.
"""

import argparse
import csv
from pathlib import Path

import joblib
import sklearn
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.model_selection import StratifiedKFold, cross_val_score, train_test_split
from sklearn.pipeline import Pipeline

RAIZ = Path(__file__).resolve().parent.parent
RUTA_CSV = RAIZ / "datasets" / "intenciones.csv"
RUTA_MODELO = RAIZ / "modelos" / "intenciones.joblib"

INTENCIONES = ["rastrear", "cotizar", "recomendar", "horarios", "saludo"]
MINIMO_POR_INTENCION = 20

PROPORCION_PRUEBA = 0.25
PLIEGUES_VALIDACION = 5
SEMILLA = 42


def cargar_dataset(ruta):
    """Lee el CSV y devuelve (textos, intenciones). Revisa columnas, etiquetas y mínimos."""
    with Path(ruta).open(newline="", encoding="utf-8") as archivo:
        lector = csv.DictReader(archivo)
        faltantes = [c for c in ("texto", "intencion") if c not in (lector.fieldnames or [])]
        if faltantes:
            raise ValueError(f"Al CSV le faltan columnas: {', '.join(faltantes)}")
        filas = [(f["texto"].strip(), f["intencion"].strip()) for f in lector]

    filas = [(texto, intencion) for texto, intencion in filas if texto]
    if not filas:
        raise ValueError("El CSV no tiene filas")
    desconocidas = sorted({i for _, i in filas} - set(INTENCIONES))
    if desconocidas:
        raise ValueError(f"Intenciones desconocidas en el CSV: {', '.join(desconocidas)}")

    textos = [texto for texto, _ in filas]
    intenciones = [intencion for _, intencion in filas]
    return textos, intenciones


def crear_modelo(semilla=SEMILLA):
    """TF-IDF de n-gramas de caracteres + regresión logística.

    Los n-gramas de caracteres toleran faltas de ortografía y palabras pegadas
    ("cuanto cuesta", "q horario"); strip_accents hace que "día" y "dia" cuenten igual.
    """
    return Pipeline([
        ("tfidf", TfidfVectorizer(
            analyzer="char_wb", ngram_range=(2, 5), lowercase=True,
            strip_accents="unicode", sublinear_tf=True,
        )),
        ("clasificador", LogisticRegression(max_iter=2000, C=10.0, random_state=semilla)),
    ])


def entrenar(textos, intenciones, semilla=SEMILLA, proporcion_prueba=PROPORCION_PRUEBA,
             pliegues=PLIEGUES_VALIDACION):
    """Separa entrenamiento y prueba, entrena y devuelve (modelo, metricas)."""
    t_ent, t_prueba, i_ent, i_prueba = train_test_split(
        textos, intenciones, test_size=proporcion_prueba, random_state=semilla,
        stratify=intenciones,
    )
    modelo = crear_modelo(semilla)
    modelo.fit(t_ent, i_ent)
    predichas = modelo.predict(t_prueba)

    # Con pocos datos, una sola partición de prueba varía mucho. La validación cruzada
    # sobre el conjunto de entrenamiento da una segunda referencia.
    validacion = cross_val_score(
        crear_modelo(semilla), t_ent, i_ent,
        cv=StratifiedKFold(n_splits=pliegues, shuffle=True, random_state=semilla),
    )

    errores = [
        {"texto": t, "real": r, "predicha": p}
        for t, r, p in zip(t_prueba, i_prueba, predichas) if r != p
    ]
    metricas = {
        "accuracy": float(accuracy_score(i_prueba, predichas)),
        "reporte": classification_report(
            i_prueba, predichas, labels=INTENCIONES, digits=3, zero_division=0,
        ),
        "matriz_confusion": confusion_matrix(i_prueba, predichas, labels=INTENCIONES).tolist(),
        "validacion_cruzada": [float(v) for v in validacion],
        "errores": errores,
        "n_entrenamiento": len(i_ent),
        "n_prueba": len(i_prueba),
    }
    return modelo, metricas


def guardar(modelo, metricas, ruta):
    ruta = Path(ruta)
    ruta.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(
        {
            "modelo": modelo,
            "intenciones": [str(c) for c in modelo.classes_],
            "sklearn_version": sklearn.__version__,
            "accuracy_prueba": metricas["accuracy"],
        },
        ruta,
        compress=3,
    )


def imprimir_metricas(metricas):
    validacion = metricas["validacion_cruzada"]
    promedio = sum(validacion) / len(validacion)
    print(f"Ejemplos de entrenamiento: {metricas['n_entrenamiento']}")
    print(f"Ejemplos de prueba:        {metricas['n_prueba']}")
    print(f"Accuracy (prueba):         {metricas['accuracy']:.4f}")
    print(f"Validación cruzada ({len(validacion)} pliegues, sobre entrenamiento): "
          f"promedio {promedio:.4f}, por pliegue "
          + ", ".join(f"{v:.4f}" for v in validacion))
    print()
    print("Reporte por intención (prueba):")
    print(metricas["reporte"])
    print("Matriz de confusión (filas = real, columnas = predicha):")
    ancho = max(len(i) for i in INTENCIONES) + 2
    print(" " * ancho + "".join(f"{i:>{ancho}}" for i in INTENCIONES))
    for intencion, fila in zip(INTENCIONES, metricas["matriz_confusion"]):
        print(f"{intencion:<{ancho}}" + "".join(f"{v:>{ancho}}" for v in fila))
    print()
    if metricas["errores"]:
        print("Errores en prueba:")
        for error in metricas["errores"]:
            print(f"  \"{error['texto']}\": real {error['real']}, predicha {error['predicha']}")
    else:
        print("Sin errores en prueba.")


def main(argv=None):
    parser = argparse.ArgumentParser(description="Entrena el clasificador de intenciones.")
    parser.add_argument("--csv", type=Path, default=RUTA_CSV)
    parser.add_argument("--salida", type=Path, default=RUTA_MODELO)
    parser.add_argument("--semilla", type=int, default=SEMILLA)
    args = parser.parse_args(argv)

    textos, intenciones = cargar_dataset(args.csv)
    conteo = {i: intenciones.count(i) for i in INTENCIONES}
    cortas = [f"{i} ({n})" for i, n in conteo.items() if n < MINIMO_POR_INTENCION]
    if cortas:
        print(f"Aviso: menos de {MINIMO_POR_INTENCION} ejemplos en: {', '.join(cortas)}")
    print(f"Dataset: {len(textos)} ejemplos; "
          + ", ".join(f"{i} {n}" for i, n in conteo.items()))

    modelo, metricas = entrenar(textos, intenciones, semilla=args.semilla)
    imprimir_metricas(metricas)
    guardar(modelo, metricas, args.salida)
    print(f"Modelo guardado en {args.salida}")
    return metricas


if __name__ == "__main__":
    main()
