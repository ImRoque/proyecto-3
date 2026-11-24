"""Pruebas del generador del dataset y del script de entrenamiento.

Corren con `python manage.py test` o con `python -m unittest entrenamiento.tests`
desde services/recomendar/.
"""

import tempfile
import unittest
from pathlib import Path

import joblib

from entrenamiento import entrenar as ent
from entrenamiento import generar_dataset as gen


class EtiquetaIdealTests(unittest.TestCase):
    def test_paquete_ligero_urgente_va_en_dron(self):
        self.assertEqual(gen.etiqueta_ideal(1.0, 5.0, True, 20.0), "dron")

    def test_paquete_ligero_cercano_no_urgente_va_en_bicicleta(self):
        self.assertEqual(gen.etiqueta_ideal(1.0, 2.0, False, 20.0), "bicicleta")

    def test_paquete_mediano_va_en_motocicleta(self):
        self.assertEqual(gen.etiqueta_ideal(15.0, 20.0, False, 40.0), "motocicleta")

    def test_paquete_pesado_va_en_camioneta(self):
        self.assertEqual(gen.etiqueta_ideal(100.0, 20.0, False, 80.0), "camioneta")

    def test_urgente_lejano_descarta_bicicleta(self):
        # 5 kg descarta el dron (R1) y urgente a 6 km descarta la bicicleta (R4).
        self.assertEqual(gen.etiqueta_ideal(5.0, 6.0, True, 30.0), "motocicleta")

    def test_paquete_grande_descarta_dron(self):
        # 1 kg pero 45 cm de lado: el dron no aplica (R3).
        self.assertNotIn("dron", gen.medios_aptos(1.0, 5.0, True, 45.0))


class GenerarDatasetTests(unittest.TestCase):
    def test_misma_semilla_da_mismo_dataset(self):
        self.assertEqual(gen.generar(200, 7), gen.generar(200, 7))

    def test_semilla_distinta_da_dataset_distinto(self):
        self.assertNotEqual(gen.generar(200, 7), gen.generar(200, 8))

    def test_filas_tienen_columnas_y_valores_validos(self):
        for fila in gen.generar(500, 1):
            self.assertEqual(list(fila), gen.COLUMNAS)
            self.assertIn(fila["medio"], gen.MEDIOS)
            self.assertIn(fila["urgente"], (0, 1))
            for columna in ("peso_kg", "distancia_km", "largo_cm", "ancho_cm", "alto_cm"):
                self.assertGreater(fila[columna], 0)

    def test_toda_etiqueta_es_un_medio_apto(self):
        # El ruido solo cambia la etiqueta por otro medio apto, nunca por uno imposible.
        for fila in gen.generar(1000, 3):
            lado = max(fila["largo_cm"], fila["ancho_cm"], fila["alto_cm"])
            aptos = gen.medios_aptos(fila["peso_kg"], fila["distancia_km"],
                                     bool(fila["urgente"]), lado)
            self.assertIn(fila["medio"], aptos)

    def test_aparecen_las_cuatro_clases(self):
        clases = {fila["medio"] for fila in gen.generar(1000, 42)}
        self.assertEqual(clases, set(gen.MEDIOS))


class EntrenarTests(unittest.TestCase):
    def setUp(self):
        self.directorio = tempfile.TemporaryDirectory()
        self.addCleanup(self.directorio.cleanup)
        self.ruta_csv = Path(self.directorio.name) / "envios.csv"
        self.ruta_modelo = Path(self.directorio.name) / "modelos" / "recomendador.joblib"
        gen.escribir_csv(gen.generar(400, 5), self.ruta_csv)

    def test_cargar_dataset_devuelve_features_en_orden(self):
        X, y = ent.cargar_dataset(self.ruta_csv)
        self.assertEqual(X.shape, (400, len(ent.FEATURES)))
        self.assertEqual(len(y), 400)

    def test_cargar_dataset_rechaza_columnas_faltantes(self):
        self.ruta_csv.write_text("peso_kg,medio\n1.0,dron\n", encoding="utf-8")
        with self.assertRaises(ValueError):
            ent.cargar_dataset(self.ruta_csv)

    def test_main_entrena_y_guarda_modelo_que_predice_clases_validas(self):
        metricas = ent.main(["--csv", str(self.ruta_csv), "--salida", str(self.ruta_modelo)])

        self.assertTrue(self.ruta_modelo.exists())
        self.assertGreaterEqual(metricas["accuracy"], 0.0)
        self.assertLessEqual(metricas["accuracy"], 1.0)
        self.assertEqual(metricas["n_prueba"], 80)

        artefacto = joblib.load(self.ruta_modelo)
        self.assertEqual(artefacto["features"], ent.FEATURES)
        self.assertEqual(sorted(artefacto["clases"]), sorted(ent.CLASES))
        prediccion = artefacto["modelo"].predict([[1.0, 5.0, 1, 20.0, 15.0, 10.0]])
        self.assertIn(prediccion[0], ent.CLASES)
        probabilidades = artefacto["modelo"].predict_proba([[1.0, 5.0, 1, 20.0, 15.0, 10.0]])
        self.assertAlmostEqual(float(probabilidades.sum()), 1.0)
