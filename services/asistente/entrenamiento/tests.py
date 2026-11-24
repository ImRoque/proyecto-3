"""Pruebas del dataset de intenciones y del script de entrenamiento.

Corren con `python manage.py test` o con `python -m unittest entrenamiento.tests`
desde services/asistente/.
"""

import tempfile
import unittest
from collections import Counter
from pathlib import Path

import joblib

from entrenamiento import entrenar as ent


class DatasetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.textos, cls.intenciones = ent.cargar_dataset(ent.RUTA_CSV)

    def test_tiene_las_cinco_intenciones_con_al_menos_20_ejemplos(self):
        conteo = Counter(self.intenciones)
        self.assertEqual(set(conteo), set(ent.INTENCIONES))
        for intencion, cantidad in conteo.items():
            with self.subTest(intencion=intencion):
                self.assertGreaterEqual(cantidad, ent.MINIMO_POR_INTENCION)

    def test_no_hay_textos_repetidos(self):
        normalizados = [t.lower().strip() for t in self.textos]
        repetidos = [t for t, n in Counter(normalizados).items() if n > 1]
        self.assertEqual(repetidos, [])

    def test_no_hay_textos_vacios(self):
        self.assertTrue(all(t.strip() for t in self.textos))


class CargarDatasetTests(unittest.TestCase):
    def setUp(self):
        self.directorio = tempfile.TemporaryDirectory()
        self.addCleanup(self.directorio.cleanup)
        self.ruta = Path(self.directorio.name) / "intenciones.csv"

    def test_rechaza_columnas_faltantes(self):
        self.ruta.write_text("mensaje,intencion\nhola,saludo\n", encoding="utf-8")
        with self.assertRaises(ValueError):
            ent.cargar_dataset(self.ruta)

    def test_rechaza_intenciones_desconocidas(self):
        self.ruta.write_text("texto,intencion\nhola,despedida\n", encoding="utf-8")
        with self.assertRaises(ValueError):
            ent.cargar_dataset(self.ruta)


class EntrenarTests(unittest.TestCase):
    def setUp(self):
        self.directorio = tempfile.TemporaryDirectory()
        self.addCleanup(self.directorio.cleanup)
        self.ruta_modelo = Path(self.directorio.name) / "modelos" / "intenciones.joblib"

    def test_main_entrena_y_guarda_un_modelo_que_clasifica(self):
        metricas = ent.main(["--salida", str(self.ruta_modelo)])

        self.assertTrue(self.ruta_modelo.exists())
        self.assertGreaterEqual(metricas["accuracy"], 0.0)
        self.assertLessEqual(metricas["accuracy"], 1.0)
        self.assertEqual(len(metricas["validacion_cruzada"]), ent.PLIEGUES_VALIDACION)

        artefacto = joblib.load(self.ruta_modelo)
        self.assertEqual(sorted(artefacto["intenciones"]), sorted(ent.INTENCIONES))
        modelo = artefacto["modelo"]
        predicha = modelo.predict(["hola, ¿me ayudas?"])[0]
        self.assertIn(predicha, ent.INTENCIONES)
        probabilidades = modelo.predict_proba(["hola, ¿me ayudas?"])[0]
        self.assertAlmostEqual(float(probabilidades.sum()), 1.0)

    def test_la_separacion_es_estratificada(self):
        textos, intenciones = ent.cargar_dataset(ent.RUTA_CSV)
        _, metricas = ent.entrenar(textos, intenciones)
        # Cada intención aparece en la prueba en la misma proporción (25 %).
        soporte_por_intencion = [sum(fila) for fila in metricas["matriz_confusion"]]
        conteo = Counter(intenciones)
        for intencion, soporte in zip(ent.INTENCIONES, soporte_por_intencion):
            with self.subTest(intencion=intencion):
                esperado = conteo[intencion] * ent.PROPORCION_PRUEBA
                self.assertLessEqual(abs(soporte - esperado), 1)
