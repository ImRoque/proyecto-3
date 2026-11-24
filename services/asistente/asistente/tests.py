import io
import json
import socket
import tempfile
import time
import urllib.error
from pathlib import Path
from unittest import mock, skipUnless

from django.test import SimpleTestCase, override_settings

from . import extraccion, modelo, textos
from .adaptador import AdaptadorChat
from .clientes import ClientePedidos, ServicioNoDisponible

URL = "/api/asistente/"
FOLIO = "PQ-20261117-7KQ3"

PEDIDO = {
    "folio": FOLIO,
    "estado": "EN_CAMINO",
    "medio": "motocicleta",
    "tipo_servicio": "express",
    "fecha_creacion": "2026-11-17T10:30:00-06:00",
    "fecha_limite": "2026-11-20",
    "actualizado_en": "2026-11-17T12:05:00-06:00",
}
RECOMENDACION = {
    "medio_modelo": "dron",
    "confianza": 0.62,
    "medio_final": "motocicleta",
    "corregido_por_reglas": True,
    "motivo": "El dron no lleva más de 2 kg (el paquete pesa 3 kg) [R1. Peso máximo]; "
              "se eligió motocicleta, el siguiente medio apto según el modelo.",
    "alternativas": [{"medio": "camioneta", "confianza": 0.05}],
}


class ModeloFijo:
    """Clasificador de prueba: devuelve la intención indicada para cada mensaje."""

    def __init__(self, intencion="saludo", confianza=0.9):
        self.intencion = intencion
        self.confianza = confianza
        self.mensajes = []

    def clasificar(self, texto):
        self.mensajes.append(texto)
        return self.intencion, self.confianza


class RespuestaHttp:
    def __init__(self, status, cuerpo):
        self.status = status
        self._cuerpo = json.dumps(cuerpo).encode("utf-8")

    def read(self):
        return self._cuerpo

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False


def error_http(url, status, cuerpo):
    return urllib.error.HTTPError(url, status, "error", {},
                                  io.BytesIO(json.dumps(cuerpo).encode("utf-8")))


class ServiciosSimulados:
    """Reemplaza urlopen: responde como pedidos y recomendar, o simula una caída."""

    def __init__(self, pedidos=None, recomendar=None):
        self.pedidos = pedidos or (lambda url: RespuestaHttp(200, PEDIDO))
        self.recomendar = recomendar or (lambda url, cuerpo: RespuestaHttp(200, RECOMENDACION))
        self.llamadas = []

    def __call__(self, peticion, timeout=None):
        url = peticion.full_url
        cuerpo = json.loads(peticion.data) if peticion.data else None
        self.llamadas.append({"url": url, "metodo": peticion.get_method(), "cuerpo": cuerpo,
                              "timeout": timeout})
        if "/api/pedidos/" in url:
            return self.pedidos(url)
        if "/api/recomendar/" in url:
            return self.recomendar(url, cuerpo)
        raise AssertionError(f"URL inesperada: {url}")


def caido(*args):
    raise urllib.error.URLError(ConnectionRefusedError("conexión rechazada"))


def sin_tiempo(*args):
    raise socket.timeout("timed out")


@override_settings(PEDIDOS_URL="http://pedidos:8000", RECOMENDAR_URL="http://recomendar:8000",
                   SERVICIOS_TIMEOUT=3)
class ChatTests(SimpleTestCase):
    def setUp(self):
        self.modelo = ModeloFijo()
        anterior = modelo.usar(self.modelo)
        self.addCleanup(modelo.usar, anterior)
        self.servicios = ServiciosSimulados()
        parche = mock.patch("asistente.clientes.urllib.request.urlopen", self.servicios)
        parche.start()
        self.addCleanup(parche.stop)

    def conversar(self, mensaje, intencion=None, confianza=0.9):
        if intencion:
            self.modelo.intencion, self.modelo.confianza = intencion, confianza
        return self.client.post(URL, data=json.dumps({"mensaje": mensaje}),
                                content_type="application/json")

    def assertChat(self, respuesta, intencion):
        self.assertEqual(respuesta.status_code, 200)
        self.assertEqual(respuesta["Content-Type"], "application/json; charset=utf-8")
        datos = respuesta.json()
        self.assertEqual(set(datos), {"intencion", "respuesta"})
        self.assertEqual(datos["intencion"], intencion)
        return datos["respuesta"]


class RastrearTests(ChatTests):
    def test_rastrear_consulta_el_folio_en_pedidos(self):
        texto = self.assertChat(self.conversar(f"¿cómo va el folio {FOLIO}?", "rastrear"),
                                "rastrear")

        self.assertIn(FOLIO, texto)
        self.assertIn("va en camino", texto)
        self.assertIn("motocicleta", texto)
        llamada = self.servicios.llamadas[0]
        self.assertEqual(llamada["url"], f"http://pedidos:8000/api/pedidos/{FOLIO}/")
        self.assertEqual(llamada["metodo"], "GET")
        self.assertEqual(llamada["timeout"], 3)

    def test_folio_en_minusculas_se_normaliza(self):
        self.conversar("rastrea pq-20261117-7kq3", "rastrear")
        self.assertIn(FOLIO, self.servicios.llamadas[0]["url"])

    def test_rastrear_sin_folio_lo_pide_sin_llamar_a_pedidos(self):
        texto = self.assertChat(self.conversar("¿dónde está mi paquete?", "rastrear"),
                                "rastrear")
        self.assertEqual(texto, textos.PEDIR_FOLIO)
        self.assertEqual(self.servicios.llamadas, [])

    def test_un_folio_solo_basta_para_rastrear(self):
        # Aunque el modelo diga otra cosa, un folio válido es rastrear.
        self.assertChat(self.conversar(FOLIO, "saludo"), "rastrear")

    def test_folio_inexistente(self):
        self.servicios.pedidos = lambda url: (_ for _ in ()).throw(error_http(
            url, 404, {"error": "no_encontrado", "detalle": "No existe"}))
        texto = self.assertChat(self.conversar(f"¿cómo va {FOLIO}?", "rastrear"), "rastrear")
        self.assertEqual(texto, textos.FOLIO_NO_ENCONTRADO.format(folio=FOLIO))

    def test_pedidos_caido_responde_amable(self):
        self.servicios.pedidos = caido
        texto = self.assertChat(self.conversar(f"¿cómo va {FOLIO}?", "rastrear"), "rastrear")
        self.assertEqual(texto, textos.PEDIDOS_NO_DISPONIBLE)

    def test_pedidos_sin_tiempo_responde_amable(self):
        self.servicios.pedidos = sin_tiempo
        texto = self.assertChat(self.conversar(f"¿cómo va {FOLIO}?", "rastrear"), "rastrear")
        self.assertEqual(texto, textos.PEDIDOS_NO_DISPONIBLE)

    def test_pedidos_responde_503_responde_amable(self):
        self.servicios.pedidos = lambda url: (_ for _ in ()).throw(error_http(
            url, 503, {"error": "servicio_no_disponible", "detalle": "caído"}))
        texto = self.assertChat(self.conversar(f"¿cómo va {FOLIO}?", "rastrear"), "rastrear")
        self.assertEqual(texto, textos.PEDIDOS_NO_DISPONIBLE)


class RecomendarTests(ChatTests):
    def test_recomendar_consulta_recomendar_y_usa_su_motivo(self):
        texto = self.assertChat(
            self.conversar("¿qué me recomiendas para 3 kg a 5 km?", "recomendar"), "recomendar")

        self.assertIn("Te recomiendo enviarlo en motocicleta", texto)
        self.assertIn(RECOMENDACION["motivo"], texto)
        self.assertIn("camioneta", texto)
        self.assertIn("Supuse una caja chica de 20×15×10 cm", texto)
        llamada = self.servicios.llamadas[0]
        self.assertEqual(llamada["url"], "http://recomendar:8000/api/recomendar/")
        self.assertEqual(llamada["metodo"], "POST")
        self.assertEqual(llamada["timeout"], 3)
        self.assertEqual(llamada["cuerpo"], {
            "peso_kg": 3.0, "distancia_km": 5.0, "urgente": False,
            "dimensiones_cm": {"largo": 20.0, "ancho": 15.0, "alto": 10.0},
        })

    def test_recomendar_con_medidas_y_urgencia_del_mensaje(self):
        texto = self.assertChat(self.conversar(
            "mando 1,5 kilos a 800 metros, 30x20x15 cm, es urgente", "recomendar"),
            "recomendar")
        self.assertNotIn("Supuse", texto)
        self.assertEqual(self.servicios.llamadas[0]["cuerpo"], {
            "peso_kg": 1.5, "distancia_km": 0.8, "urgente": True,
            "dimensiones_cm": {"largo": 30.0, "ancho": 20.0, "alto": 15.0},
        })

    def test_recomendar_sin_peso_ni_distancia_los_pide(self):
        texto = self.assertChat(self.conversar("¿en qué mando mi paquete?", "recomendar"),
                                "recomendar")
        self.assertIn("el peso", texto)
        self.assertIn("la distancia", texto)
        self.assertEqual(self.servicios.llamadas, [])

    def test_recomendar_sin_distancia_pide_solo_la_distancia(self):
        texto = self.assertChat(self.conversar("¿cómo mando 3 kg?", "recomendar"), "recomendar")
        self.assertNotIn("el peso", texto)
        self.assertIn("la distancia", texto)

    def test_sin_medio_apto_usa_el_detalle_de_recomendar(self):
        detalle = "Ningún medio cumple las reglas de negocio: La camioneta no lleva más de 1000 kg"
        self.servicios.recomendar = lambda url, cuerpo: (_ for _ in ()).throw(error_http(
            url, 400, {"error": "sin_medio_apto", "detalle": detalle}))
        texto = self.assertChat(self.conversar("2000 kg a 5 km", "recomendar"), "recomendar")
        self.assertIn(detalle, texto)

    def test_recomendar_caido_responde_amable(self):
        self.servicios.recomendar = caido
        texto = self.assertChat(self.conversar("3 kg a 5 km", "recomendar"), "recomendar")
        self.assertEqual(texto, textos.RECOMENDAR_NO_DISPONIBLE)

    def test_recomendar_sin_modelo_responde_amable(self):
        self.servicios.recomendar = lambda url, cuerpo: (_ for _ in ()).throw(error_http(
            url, 503, {"error": "modelo_no_disponible", "detalle": "sin modelo"}))
        texto = self.assertChat(self.conversar("3 kg a 5 km", "recomendar"), "recomendar")
        self.assertEqual(texto, textos.RECOMENDAR_NO_DISPONIBLE)


class RespuestasFijasTests(ChatTests):
    def test_respuestas_fijas_no_llaman_a_otros_servicios(self):
        casos = {"horarios": textos.HORARIOS, "saludo": textos.SALUDO,
                 "cotizar": textos.COTIZAR}
        for intencion, esperado in casos.items():
            with self.subTest(intencion=intencion):
                texto = self.assertChat(self.conversar("mensaje", intencion), intencion)
                self.assertEqual(texto, esperado)
        self.assertEqual(self.servicios.llamadas, [])

    def test_respuestas_fijas_funcionan_con_servicios_caidos(self):
        self.servicios.pedidos = caido
        self.servicios.recomendar = caido
        self.assertChat(self.conversar("¿qué horarios tienen?", "horarios"), "horarios")

    def test_confianza_baja_es_desconocida(self):
        texto = self.assertChat(self.conversar("¿venden pizzas?", "horarios", confianza=0.3),
                                "desconocida")
        self.assertEqual(texto, textos.DESCONOCIDA)


class ErroresTests(ChatTests):
    def assertError(self, respuesta, status, codigo):
        self.assertEqual(respuesta.status_code, status)
        self.assertEqual(respuesta["Content-Type"], "application/json; charset=utf-8")
        self.assertEqual(respuesta.json()["error"], codigo)

    def post(self, crudo):
        return self.client.post(URL, data=crudo, content_type="application/json")

    def test_mensaje_vacio(self):
        for cuerpo in ({"mensaje": ""}, {"mensaje": "   "}, {}, {"mensaje": None}):
            with self.subTest(cuerpo=cuerpo):
                self.assertError(self.post(json.dumps(cuerpo)), 400, "mensaje_vacio")
        self.assertEqual(self.modelo.mensajes, [])

    def test_datos_invalidos(self):
        casos = ["no es json", "[1, 2]", json.dumps({"mensaje": 5}),
                 json.dumps({"mensaje": "a" * 501})]
        for crudo in casos:
            with self.subTest(crudo=crudo[:20]):
                self.assertError(self.post(crudo), 400, "datos_invalidos")

    def test_mensaje_de_500_caracteres_se_acepta(self):
        self.assertEqual(self.post(json.dumps({"mensaje": "a" * 500})).status_code, 200)

    def test_sin_modelo_responde_503(self):
        modelo.usar(None)
        self.assertError(self.post(json.dumps({"mensaje": "hola"})), 503,
                         "modelo_no_disponible")

    def test_archivo_inexistente_deja_el_chat_en_503(self):
        with tempfile.TemporaryDirectory() as carpeta:
            self.assertFalse(modelo.cargar(Path(carpeta) / "no-existe.joblib"))
        respuesta = self.post(json.dumps({"mensaje": "hola"}))
        self.assertError(respuesta, 503, "modelo_no_disponible")
        self.assertIn("no-existe.joblib", respuesta.json()["detalle"])

    def test_el_modelo_no_se_vuelve_a_leer_en_la_peticion(self):
        with mock.patch("asistente.modelo.joblib.load") as carga:
            self.post(json.dumps({"mensaje": "hola"}))
            self.post(json.dumps({"mensaje": "hola"}))
        carga.assert_not_called()

    def test_get_en_el_chat_responde_404_json(self):
        self.assertError(self.client.get(URL), 404, "ruta_no_encontrada")

    def test_ruta_inexistente_responde_404_json(self):
        self.assertError(self.client.get("/api/asistente/no-existe/"), 404,
                         "ruta_no_encontrada")


class HealthTests(SimpleTestCase):
    def test_health_responde_200_con_json_acordado(self):
        respuesta = self.client.get("/api/asistente/health/")

        self.assertEqual(respuesta.status_code, 200)
        self.assertEqual(respuesta["Content-Type"], "application/json; charset=utf-8")
        self.assertEqual(respuesta.json(), {"servicio": "asistente", "ok": True})


class ExtraccionTests(SimpleTestCase):
    def test_folio(self):
        self.assertEqual(extraccion.extraer_folio(f"¿cómo va {FOLIO}?"), FOLIO)
        self.assertEqual(extraccion.extraer_folio("pq-20261117-7kq3"), FOLIO)
        self.assertIsNone(extraccion.extraer_folio("PQ-2026111-7KQ3"))  # fecha corta
        self.assertIsNone(extraccion.extraer_folio("PQ-20261117-7KQ0"))  # 0 no se usa
        self.assertIsNone(extraccion.extraer_folio("mi pedido"))

    def test_peso(self):
        casos = {"3 kg": 3.0, "1,5 kilos": 1.5, "2.5kg": 2.5, "800 gramos": 0.8,
                 "un kilo": None, "10 kilogramos": 10.0, "500 g": 0.5}
        for texto, esperado in casos.items():
            with self.subTest(texto=texto):
                self.assertEqual(extraccion.extraer_peso_kg(texto), esperado)

    def test_distancia(self):
        casos = {"5 km": 5.0, "12 kilómetros": 12.0, "7 kilometros": 7.0,
                 "800 metros": 0.8, "lejos": None}
        for texto, esperado in casos.items():
            with self.subTest(texto=texto):
                self.assertEqual(extraccion.extraer_distancia_km(texto), esperado)

    def test_kilometros_no_cuentan_como_peso(self):
        self.assertIsNone(extraccion.extraer_peso_kg("5 kilometros"))
        self.assertIsNone(extraccion.extraer_peso_kg("5 kilómetros"))

    def test_medidas(self):
        self.assertEqual(extraccion.extraer_dimensiones_cm("caja de 30x20x15 cm"),
                         {"largo": 30.0, "ancho": 20.0, "alto": 15.0})
        self.assertEqual(extraccion.extraer_dimensiones_cm("40 × 30 × 20"),
                         {"largo": 40.0, "ancho": 30.0, "alto": 20.0})
        self.assertIsNone(extraccion.extraer_dimensiones_cm("30x20 cm"))

    def test_urgencia(self):
        self.assertTrue(extraccion.extraer_urgente("es urgente"))
        self.assertTrue(extraccion.extraer_urgente("me urge"))
        self.assertFalse(extraccion.extraer_urgente("no es urgente"))
        self.assertFalse(extraccion.extraer_urgente("3 kg a 5 km"))


class AdaptadorTests(SimpleTestCase):
    def test_pedido_entregado_no_muestra_fecha_limite(self):
        texto = AdaptadorChat().pedido({**PEDIDO, "estado": "ENTREGADO"})
        self.assertIn("ya fue entregado", texto)
        self.assertNotIn("Fecha límite", texto)

    def test_recomendacion_sin_alternativas(self):
        texto = AdaptadorChat().recomendacion({**RECOMENDACION, "alternativas": []})
        self.assertNotIn("Otras opciones", texto)


class ClientePedidosTests(SimpleTestCase):
    def test_el_tiempo_limite_cubre_toda_la_llamada(self):
        # Simula una búsqueda DNS lenta, que el timeout de urlopen no corta.
        def lento(peticion, timeout=None):
            time.sleep(2)
            return RespuestaHttp(200, PEDIDO)

        with mock.patch("asistente.clientes.urllib.request.urlopen", lento):
            inicio = time.monotonic()
            with self.assertRaises(ServicioNoDisponible):
                ClientePedidos("http://pedidos:8000", timeout=0.2).consultar(FOLIO)
        self.assertLess(time.monotonic() - inicio, 1.0)

    def test_respuesta_que_no_es_json_cuenta_como_no_disponible(self):
        class NoJson(RespuestaHttp):
            def read(self):
                return b"<html>"

        with mock.patch("asistente.clientes.urllib.request.urlopen",
                        lambda peticion, timeout=None: NoJson(200, {})):
            with self.assertRaises(ServicioNoDisponible):
                ClientePedidos("http://pedidos:8000", timeout=3).consultar(FOLIO)


@skipUnless(modelo.ruta_configurada().exists(), "No hay modelos/intenciones.joblib")
class ModeloRealTests(SimpleTestCase):
    """Con el .joblib real, si existe en esta copia del repositorio."""

    def setUp(self):
        anterior = modelo.obtener()
        self.addCleanup(modelo.usar, anterior)
        self.assertTrue(modelo.cargar())

    def test_mensajes_de_ejemplo_se_clasifican_bien(self):
        casos = {
            "¿qué me recomiendas para 3 kg a 5 km?": "recomendar",
            "¿qué horarios tienen?": "horarios",
            "¿cuánto cuesta mandar 2 kilos?": "cotizar",
            "hola": "saludo",
        }
        for mensaje, esperada in casos.items():
            with self.subTest(mensaje=mensaje):
                self.assertEqual(modelo.obtener().clasificar(mensaje)[0], esperada)
