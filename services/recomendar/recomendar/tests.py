import json
import tempfile
from pathlib import Path
from unittest import mock, skipUnless

from django.test import SimpleTestCase

from . import modelo
from .reglas import (ReglaDistanciaMaxima, ReglaPesoMaximo, ReglaTamanoPaquete,
                     ReglaUrgencia)
from .validacion import Envio

URL = "/api/recomendar/"


class ModeloFijo:
    """Modelo de prueba que siempre devuelve las mismas probabilidades."""

    def __init__(self, probabilidades):
        self._probabilidades = probabilidades

    def probabilidades(self, envio):
        return dict(self._probabilidades)


class ModeloRoto:
    def probabilidades(self, envio):
        raise RuntimeError("falla interna")


def cuerpo(peso=3.5, distancia=6.0, urgente=False, largo=30, ancho=20, alto=15):
    return {
        "peso_kg": peso,
        "distancia_km": distancia,
        "urgente": urgente,
        "dimensiones_cm": {"largo": largo, "ancho": ancho, "alto": alto},
    }


class ConModeloDePrueba(SimpleTestCase):
    """Cambia el modelo cargado por uno fijo y lo restaura al terminar."""

    probabilidades = None

    def setUp(self):
        anterior = modelo.usar(ModeloFijo(self.probabilidades) if self.probabilidades else None)
        self.addCleanup(modelo.usar, anterior)

    def post(self, datos, crudo=None):
        return self.client.post(
            URL, data=crudo if crudo is not None else json.dumps(datos),
            content_type="application/json",
        )


class HealthTests(SimpleTestCase):
    def test_health_responde_200_con_json_acordado(self):
        respuesta = self.client.get("/api/recomendar/health/")

        self.assertEqual(respuesta.status_code, 200)
        self.assertEqual(respuesta["Content-Type"], "application/json; charset=utf-8")
        self.assertEqual(respuesta.json(), {"servicio": "recomendar", "ok": True})


class ModeloAciertaTests(ConModeloDePrueba):
    probabilidades = {"dron": 0.7, "motocicleta": 0.2, "bicicleta": 0.06, "camioneta": 0.04}

    def test_modelo_acierta_y_no_se_corrige(self):
        # 1 kg, 5 km, urgente, 20 cm: el dron cumple R1 a R4.
        respuesta = self.post(cuerpo(peso=1, distancia=5, urgente=True, largo=20, ancho=15,
                                     alto=10))

        self.assertEqual(respuesta.status_code, 200)
        self.assertEqual(respuesta["Content-Type"], "application/json; charset=utf-8")
        datos = respuesta.json()
        self.assertEqual(datos["medio_modelo"], "dron")
        self.assertEqual(datos["medio_final"], "dron")
        self.assertIs(datos["corregido_por_reglas"], False)
        self.assertEqual(datos["confianza"], 0.7)
        self.assertIn("cumple todas las reglas", datos["motivo"])
        # La bicicleta no aparece: urgente a más de 3 km (R4).
        self.assertEqual(datos["alternativas"], [
            {"medio": "motocicleta", "confianza": 0.2},
            {"medio": "camioneta", "confianza": 0.04},
        ])

    def test_respuesta_trae_todos_los_campos_del_contrato(self):
        datos = self.post(cuerpo(peso=1, distancia=5, urgente=True, largo=20)).json()
        self.assertEqual(set(datos), {"medio_modelo", "confianza", "medio_final",
                                      "corregido_por_reglas", "motivo", "alternativas"})

    def test_el_modelo_no_se_vuelve_a_leer_en_la_peticion(self):
        with mock.patch("recomendar.modelo.joblib.load") as carga:
            self.post(cuerpo(peso=1, distancia=5, urgente=True, largo=20))
            self.post(cuerpo(peso=1, distancia=5, urgente=True, largo=20))
        carga.assert_not_called()


class ReglaCorrigeAlModeloTests(ConModeloDePrueba):
    # Mismas probabilidades que el ejemplo de docs/api.md.
    probabilidades = {"dron": 0.62, "motocicleta": 0.25, "bicicleta": 0.08, "camioneta": 0.05}

    def test_regla_de_peso_corrige_al_modelo(self):
        respuesta = self.post(cuerpo(peso=3.5, distancia=6.0, urgente=False))

        self.assertEqual(respuesta.status_code, 200)
        datos = respuesta.json()
        self.assertEqual(datos["medio_modelo"], "dron")
        self.assertEqual(datos["medio_final"], "motocicleta")
        self.assertNotEqual(datos["medio_modelo"], datos["medio_final"])
        self.assertIs(datos["corregido_por_reglas"], True)
        self.assertEqual(datos["confianza"], 0.62)
        self.assertIn("El dron no lleva más de 2 kg", datos["motivo"])
        self.assertIn("R1", datos["motivo"])
        self.assertEqual(datos["alternativas"], [
            {"medio": "bicicleta", "confianza": 0.08},
            {"medio": "camioneta", "confianza": 0.05},
        ])

    def test_regla_de_tamano_corrige_al_modelo(self):
        # 1 kg y 3 km, pero 45 cm de lado: R3 descarta el dron.
        datos = self.post(cuerpo(peso=1, distancia=3, largo=45, ancho=10, alto=10)).json()
        self.assertEqual(datos["medio_final"], "motocicleta")
        self.assertIs(datos["corregido_por_reglas"], True)
        self.assertIn("R3", datos["motivo"])

    def test_sin_medio_apto_responde_400(self):
        respuesta = self.post(cuerpo(peso=2000, distancia=6))

        self.assertEqual(respuesta.status_code, 400)
        self.assertEqual(respuesta.json()["error"], "sin_medio_apto")


class DatosInvalidosTests(ConModeloDePrueba):
    probabilidades = {"dron": 0.62, "motocicleta": 0.25, "bicicleta": 0.08, "camioneta": 0.05}

    def assertDatosInvalidos(self, respuesta):
        self.assertEqual(respuesta.status_code, 400)
        self.assertEqual(respuesta["Content-Type"], "application/json; charset=utf-8")
        self.assertEqual(respuesta.json()["error"], "datos_invalidos")
        self.assertTrue(respuesta.json()["detalle"])

    def test_faltan_campos(self):
        for campo in ("peso_kg", "distancia_km", "urgente", "dimensiones_cm"):
            with self.subTest(campo=campo):
                datos = cuerpo()
                del datos[campo]
                self.assertDatosInvalidos(self.post(datos))

    def test_falta_una_medida(self):
        datos = cuerpo()
        del datos["dimensiones_cm"]["alto"]
        self.assertDatosInvalidos(self.post(datos))

    def test_valores_invalidos(self):
        casos = {
            "peso negativo": cuerpo(peso=-1),
            "peso cero": cuerpo(peso=0),
            "peso como texto": cuerpo(peso="3"),
            "peso booleano": cuerpo(peso=True),
            "distancia nula": {**cuerpo(), "distancia_km": None},
            "urgente como texto": cuerpo(urgente="si"),
            "urgente como número": cuerpo(urgente=1),
            "medida negativa": cuerpo(alto=-5),
            "dimensiones como lista": {**cuerpo(), "dimensiones_cm": [30, 20, 15]},
        }
        for nombre, datos in casos.items():
            with self.subTest(nombre):
                self.assertDatosInvalidos(self.post(datos))

    def test_cuerpo_que_no_es_json(self):
        self.assertDatosInvalidos(self.post(None, crudo="esto no es json"))

    def test_cuerpo_que_no_es_objeto(self):
        self.assertDatosInvalidos(self.post(None, crudo="[1, 2, 3]"))


class ModeloNoDisponibleTests(ConModeloDePrueba):
    probabilidades = None

    def test_sin_modelo_responde_503_modelo_no_disponible(self):
        respuesta = self.post(cuerpo())

        self.assertEqual(respuesta.status_code, 503)
        self.assertEqual(respuesta.json()["error"], "modelo_no_disponible")

    def test_archivo_inexistente_deja_el_servicio_en_503(self):
        with tempfile.TemporaryDirectory() as carpeta:
            self.assertFalse(modelo.cargar(Path(carpeta) / "no-existe.joblib"))
        respuesta = self.post(cuerpo())

        self.assertEqual(respuesta.status_code, 503)
        self.assertEqual(respuesta.json()["error"], "modelo_no_disponible")
        self.assertIn("no-existe.joblib", respuesta.json()["detalle"])

    def test_archivo_danado_deja_el_servicio_en_503(self):
        with tempfile.TemporaryDirectory() as carpeta:
            ruta = Path(carpeta) / "danado.joblib"
            ruta.write_bytes(b"no es un modelo")
            self.assertFalse(modelo.cargar(ruta))
        self.assertEqual(self.post(cuerpo()).status_code, 503)

    def test_falla_al_predecir_responde_503(self):
        modelo.usar(ModeloRoto())
        respuesta = self.post(cuerpo())

        self.assertEqual(respuesta.status_code, 503)
        self.assertEqual(respuesta.json()["error"], "modelo_no_disponible")

    def test_datos_invalidos_se_revisan_antes_que_el_modelo(self):
        self.assertEqual(self.post(cuerpo(peso=-1)).status_code, 400)


class RutasTests(SimpleTestCase):
    def test_get_en_la_ruta_de_recomendar_responde_404_json(self):
        respuesta = self.client.get(URL)
        self.assertEqual(respuesta.status_code, 404)
        self.assertEqual(respuesta.json()["error"], "ruta_no_encontrada")

    def test_ruta_inexistente_responde_404_json(self):
        respuesta = self.client.get("/api/recomendar/no-existe/")
        self.assertEqual(respuesta.status_code, 404)
        self.assertEqual(respuesta.json()["error"], "ruta_no_encontrada")


class ReglasTests(SimpleTestCase):
    """Cada estrategia por separado, con la misma interfaz `descarta(envio, medio)`."""

    def envio(self, peso=1.0, distancia=2.0, urgente=False, largo=20.0):
        return Envio(peso, distancia, urgente, largo, 10.0, 10.0)

    def test_peso_maximo(self):
        regla = ReglaPesoMaximo()
        self.assertIsNone(regla.descarta(self.envio(peso=2.0), "dron"))
        self.assertIn("2 kg", regla.descarta(self.envio(peso=2.1), "dron"))
        self.assertIsNone(regla.descarta(self.envio(peso=2.1), "motocicleta"))

    def test_distancia_maxima(self):
        regla = ReglaDistanciaMaxima()
        self.assertIsNone(regla.descarta(self.envio(distancia=8), "bicicleta"))
        self.assertIn("8 km", regla.descarta(self.envio(distancia=8.5), "bicicleta"))

    def test_tamano_del_paquete(self):
        regla = ReglaTamanoPaquete()
        self.assertIsNone(regla.descarta(self.envio(largo=40), "dron"))
        self.assertIn("40 cm", regla.descarta(self.envio(largo=41), "dron"))

    def test_urgencia(self):
        regla = ReglaUrgencia()
        self.assertIsNone(regla.descarta(self.envio(urgente=True, distancia=3), "bicicleta"))
        self.assertIsNotNone(regla.descarta(self.envio(urgente=True, distancia=4), "bicicleta"))
        self.assertIsNone(regla.descarta(self.envio(urgente=False, distancia=4), "bicicleta"))
        self.assertIsNone(regla.descarta(self.envio(urgente=True, distancia=4), "motocicleta"))


@skipUnless(modelo.ruta_configurada().exists(), "No hay modelos/recomendador.joblib")
class ModeloRealTests(SimpleTestCase):
    """Con el .joblib real, si existe en esta copia del repositorio."""

    def setUp(self):
        anterior = modelo.obtener()
        self.addCleanup(modelo.usar, anterior)
        self.assertTrue(modelo.cargar())

    def test_modelo_real_responde_con_el_contrato(self):
        respuesta = self.client.post(URL, data=json.dumps(cuerpo()),
                                     content_type="application/json")
        self.assertEqual(respuesta.status_code, 200)
        datos = respuesta.json()
        self.assertIn(datos["medio_final"], ("camioneta", "motocicleta", "bicicleta", "dron"))
        self.assertGreaterEqual(datos["confianza"], 0)
        self.assertLessEqual(datos["confianza"], 1)
