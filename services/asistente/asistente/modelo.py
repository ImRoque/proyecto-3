"""Carga del clasificador de intenciones (modelos/intenciones.joblib).

El modelo se carga UNA vez, al iniciar el servicio (AsistenteConfig.ready). Las peticiones
solo usan el modelo ya cargado; nunca se entrena ni se vuelve a leer el archivo. Si el
archivo falta o no se puede leer, el servicio arranca igual y el chat responde 503
modelo_no_disponible.
"""
import logging
import os
from pathlib import Path

import joblib
import sklearn

logger = logging.getLogger(__name__)

RUTA_POR_DEFECTO = Path(__file__).resolve().parent.parent / "modelos" / "intenciones.joblib"
INTENCIONES_ENTRENADAS = {"rastrear", "cotizar", "recomendar", "horarios", "saludo"}


class ModeloIntenciones:
    """Envuelve el pipeline TF-IDF + regresión logística."""

    def __init__(self, pipeline):
        clases = {str(c) for c in pipeline.classes_}
        if clases != INTENCIONES_ENTRENADAS:
            raise ValueError(f"Intenciones inesperadas en el modelo: {sorted(clases)}")
        self.pipeline = pipeline

    def clasificar(self, texto):
        """Devuelve (intencion, confianza) con la intención de mayor probabilidad."""
        probabilidades = self.pipeline.predict_proba([texto])[0]
        indice = int(probabilidades.argmax())
        return str(self.pipeline.classes_[indice]), float(probabilidades[indice])


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
        modelo = ModeloIntenciones(artefacto["modelo"])
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
