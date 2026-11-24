"""Carga del modelo entrenado (modelos/recomendador.joblib).

El modelo se carga UNA vez, al iniciar el servicio (RecomendarConfig.ready). Las peticiones
solo leen el modelo ya cargado; nunca se entrena ni se vuelve a leer el archivo en una
petición. Si el archivo falta o no se puede leer, el servicio arranca igual y la ruta de
recomendación responde 503 modelo_no_disponible.
"""
import logging
import os
from pathlib import Path

import joblib
import sklearn

logger = logging.getLogger(__name__)

RUTA_POR_DEFECTO = Path(__file__).resolve().parent.parent / "modelos" / "recomendador.joblib"
FEATURES_ESPERADAS = ["peso_kg", "distancia_km", "urgente", "largo_cm", "ancho_cm", "alto_cm"]


class ModeloRecomendador:
    """Envuelve el clasificador de scikit-learn y su orden de features."""

    def __init__(self, clasificador, features):
        if list(features) != FEATURES_ESPERADAS:
            raise ValueError(f"Features inesperadas en el modelo: {features}")
        self.clasificador = clasificador
        self.features = list(features)

    def probabilidades(self, envio):
        """Probabilidad por medio, por ejemplo {"dron": 0.62, "motocicleta": 0.25, ...}."""
        valores = envio.como_features()
        fila = [[valores[nombre] for nombre in self.features]]
        probabilidades = self.clasificador.predict_proba(fila)[0]
        return {
            str(clase): float(p)
            for clase, p in zip(self.clasificador.classes_, probabilidades)
        }


_modelo = None
_error_carga = "El modelo no se ha cargado"


def ruta_configurada():
    return Path(os.environ.get("MODELO_RUTA") or RUTA_POR_DEFECTO)


def cargar(ruta=None):
    """Lee el .joblib y lo deja listo para las peticiones. Devuelve True si se cargó."""
    global _modelo, _error_carga
    ruta = Path(ruta) if ruta else ruta_configurada()
    try:
        artefacto = joblib.load(ruta)
        modelo = ModeloRecomendador(artefacto["modelo"], artefacto["features"])
    except FileNotFoundError:
        _modelo, _error_carga = None, f"No existe el archivo del modelo {ruta.name}"
        logger.warning("Modelo no disponible: no existe %s", ruta)
        return False
    except Exception as error:  # archivo dañado, formato distinto, versión incompatible
        _modelo, _error_carga = None, "No se pudo leer el archivo del modelo"
        logger.error("Modelo no disponible: no se pudo cargar %s (%s)", ruta, error)
        return False

    version = artefacto.get("sklearn_version")
    if version and version != sklearn.__version__:
        logger.warning("El modelo se entrenó con scikit-learn %s y se cargó con %s",
                       version, sklearn.__version__)
    _modelo, _error_carga = modelo, None
    logger.info("Modelo cargado desde %s", ruta)
    return True


def obtener():
    """Modelo cargado, o None si no está disponible."""
    return _modelo


def error_carga():
    return _error_carga


def usar(modelo):
    """Reemplaza el modelo cargado (para pruebas). Devuelve el anterior."""
    global _modelo, _error_carga
    anterior = _modelo
    _modelo = modelo
    _error_carga = None if modelo else "El modelo no se ha cargado"
    return anterior
