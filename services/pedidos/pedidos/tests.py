import datetime
import http.server
import json
import re
import socket
import threading
import time
import urllib.error
import uuid
from unittest import mock

from django.test import SimpleTestCase, TestCase, override_settings
from django.utils import timezone

from .cliente_catalogo import CatalogoNoDisponible, ClienteCatalogo
from .confirmacion import calcular_costo
from .models import Pedido
from .repositorio import PedidoRepositorio

CONTENT_TYPE = "application/json; charset=utf-8"
URL = "/api/pedidos/"
FOLIO_RE = re.compile(r"^PQ-\d{8}-[A-HJ-NP-Z2-9]{4}$")

# Mismos valores que services/catalogo/catalogo/fixtures/catalogo_inicial.json.
MEDIOS = {
    "motocicleta": {
        "clave": "motocicleta", "peso_max_kg": 20, "distancia_max_km": 40,
        "costo_base": 40.0, "costo_por_km": 4.5,
    },
    "dron": {
        "clave": "dron", "peso_max_kg": 2, "distancia_max_km": 10,
        "costo_base": 80.0, "costo_por_km": 6.0,
    },
}
TIPOS = {
    "estandar": {"clave": "estandar", "multiplicador_costo": 1.0},
    "express": {"clave": "express", "multiplicador_costo": 1.5},
}


class CatalogoFalso:
    """Sustituye al cliente HTTP de catalogo en las pruebas."""

    def __init__(self, caido=False):
        self.caido = caido

    def obtener_medio(self, clave):
        if self.caido:
            raise CatalogoNoDisponible("sin conexión")
        return MEDIOS.get(clave)

    def obtener_tipo_servicio(self, clave):
        if self.caido:
            raise CatalogoNoDisponible("sin conexión")
        return TIPOS.get(clave)


def cuerpo_valido(**cambios):
    datos = {
        "origen": "Av. Juárez 100, Centro, Guadalajara",
        "destino": "Calle Hidalgo 25, Zapopan",
        "distancia_km": 8.5,
        "peso_kg": 2.3,
        "dimensiones_cm": {"largo": 30, "ancho": 20, "alto": 15},
        "urgente": False,
        "seguro": True,
        "fecha_limite": (timezone.localdate() + datetime.timedelta(days=3)).isoformat(),
        "medio": "motocicleta",
        "tipo_servicio": "express",
    }
    datos.update(cambios)
    return datos


class BasePedidos(TestCase):
    catalogo_caido = False

    def setUp(self):
        parche = mock.patch(
            "pedidos.confirmacion.ClienteCatalogo",
            return_value=CatalogoFalso(caido=self.catalogo_caido),
        )
        parche.start()
        self.addCleanup(parche.stop)

    def registrar(self, datos=None, clave=None, cuerpo_crudo=None):
        cuerpo = cuerpo_crudo if cuerpo_crudo is not None else json.dumps(
            datos if datos is not None else cuerpo_valido()
        )
        encabezados = {}
        if clave is not False:
            encabezados["HTTP_IDEMPOTENCY_KEY"] = clave or str(uuid.uuid4())
        return self.client.post(URL, cuerpo, content_type=CONTENT_TYPE, **encabezados)

    def cambiar(self, folio, estado):
        return self.client.patch(
            f"{URL}{folio}/estado/", json.dumps({"estado": estado}), content_type=CONTENT_TYPE
        )

    def assertError(self, respuesta, status, codigo):
        self.assertEqual(respuesta.status_code, status, respuesta.content)
        self.assertEqual(respuesta["Content-Type"], CONTENT_TYPE)
        self.assertEqual(respuesta.json()["error"], codigo)
        self.assertIn("detalle", respuesta.json())


class HealthTests(SimpleTestCase):
    def test_health_responde_200_con_json_acordado(self):
        respuesta = self.client.get("/api/pedidos/health/")

        self.assertEqual(respuesta.status_code, 200)
        self.assertEqual(respuesta["Content-Type"], CONTENT_TYPE)
        self.assertEqual(respuesta.json(), {"servicio": "pedidos", "ok": True})


class RegistroTests(BasePedidos):

    def test_crear_pedido_devuelve_201_con_folio(self):
        respuesta = self.registrar()

        self.assertEqual(respuesta.status_code, 201, respuesta.content)
        self.assertEqual(respuesta["Content-Type"], CONTENT_TYPE)
        datos = respuesta.json()
        self.assertRegex(datos["folio"], FOLIO_RE)
        self.assertIn(timezone.localdate().strftime("%Y%m%d"), datos["folio"])
        self.assertEqual(datos["estado"], "CREADO")
        self.assertEqual(datos["moneda"], "MXN")
        self.assertEqual(
            set(datos),
            {
                "folio", "estado", "origen", "destino", "distancia_km", "peso_kg",
                "dimensiones_cm", "urgente", "seguro", "fecha_limite", "medio",
                "tipo_servicio", "costo", "moneda", "fecha_creacion",
            },
        )
        self.assertEqual(Pedido.objects.count(), 1)

    def test_costo_del_ejemplo_del_contrato(self):
        # (40 + 4.5 * 8.5) * 1.5 = 117.375; + 10 % de seguro = 129.1125 -> 129.11
        self.assertEqual(self.registrar().json()["costo"], 129.11)

    def test_costo_sin_seguro(self):
        datos = self.registrar(cuerpo_valido(seguro=False, tipo_servicio="estandar")).json()

        self.assertEqual(datos["costo"], 78.25)

    def test_calcular_costo_redondea_a_dos_decimales(self):
        costo = calcular_costo(MEDIOS["dron"], TIPOS["express"], 1.111, True)

        # (80 + 6 * 1.111) * 1.5 * 1.1 = 142.99902 -> 143.00
        self.assertEqual(str(costo), "143.00")

    def test_fecha_creacion_en_iso_8601_con_zona(self):
        fecha = self.registrar().json()["fecha_creacion"]

        self.assertRegex(fecha, r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$")


class IdempotenciaTests(BasePedidos):

    def test_misma_clave_y_mismo_cuerpo_devuelve_el_mismo_folio(self):
        clave = str(uuid.uuid4())
        primera = self.registrar(clave=clave)
        segunda = self.registrar(clave=clave)

        self.assertEqual(primera.status_code, 201)
        self.assertEqual(segunda.status_code, 200)
        self.assertEqual(primera.json(), segunda.json())
        self.assertEqual(Pedido.objects.count(), 1)

    def test_orden_distinto_de_campos_cuenta_como_mismo_cuerpo(self):
        clave = str(uuid.uuid4())
        datos = cuerpo_valido()
        self.registrar(datos, clave=clave)
        al_reves = dict(reversed(list(datos.items())))

        self.assertEqual(self.registrar(al_reves, clave=clave).status_code, 200)

    def test_misma_clave_con_cuerpo_distinto_responde_409(self):
        clave = str(uuid.uuid4())
        self.registrar(clave=clave)
        respuesta = self.registrar(cuerpo_valido(peso_kg=5), clave=clave)

        self.assertError(respuesta, 409, "idempotency_key_reutilizada")
        self.assertEqual(Pedido.objects.count(), 1)

    def test_carrera_la_restriccion_unica_evita_el_duplicado(self):
        """Simula dos peticiones simultáneas: la segunda no vio el pedido de la primera
        en la consulta previa, así que llega hasta el INSERT y choca con la restricción
        única de la base."""
        clave = str(uuid.uuid4())
        folio = self.registrar(clave=clave).json()["folio"]

        original = PedidoRepositorio.buscar_por_clave
        llamadas = []

        def no_lo_ve_la_primera_vez(repositorio, valor):
            llamadas.append(valor)
            return None if len(llamadas) == 1 else original(repositorio, valor)

        with mock.patch.object(PedidoRepositorio, "buscar_por_clave", no_lo_ve_la_primera_vez):
            respuesta = self.registrar(clave=clave)

        self.assertEqual(len(llamadas), 2)  # consulta previa + relectura tras el choque
        self.assertEqual(respuesta.status_code, 200)
        self.assertEqual(respuesta.json()["folio"], folio)
        self.assertEqual(Pedido.objects.count(), 1)

    def test_sin_idempotency_key_responde_400(self):
        self.assertError(self.registrar(clave=False), 400, "falta_idempotency_key")

    def test_idempotency_key_que_no_es_uuid_v4_responde_400(self):
        for clave in ("abc", str(uuid.uuid1())):
            with self.subTest(clave=clave):
                self.assertError(self.registrar(clave=clave), 400, "falta_idempotency_key")
        self.assertEqual(Pedido.objects.count(), 0)


class ValidacionTests(BasePedidos):

    def test_json_invalido_responde_400(self):
        self.assertError(self.registrar(cuerpo_crudo="{no es json"), 400, "datos_invalidos")

    def test_cuerpo_que_no_es_objeto_responde_400(self):
        self.assertError(self.registrar(cuerpo_crudo="[1, 2]"), 400, "datos_invalidos")

    def test_cada_campo_faltante_responde_400(self):
        for campo in cuerpo_valido():
            with self.subTest(campo=campo):
                datos = cuerpo_valido()
                del datos[campo]
                self.assertError(self.registrar(datos), 400, "datos_invalidos")
        self.assertEqual(Pedido.objects.count(), 0)

    def test_valores_invalidos_responden_400(self):
        casos = {
            "peso negativo": {"peso_kg": -1},
            "peso cero": {"peso_kg": 0},
            "distancia como texto": {"distancia_km": "8"},
            "booleano como número": {"peso_kg": True},
            "medida faltante": {"dimensiones_cm": {"largo": 30, "ancho": 20}},
            "medida en cero": {"dimensiones_cm": {"largo": 30, "ancho": 0, "alto": 15}},
            "dimensiones no objeto": {"dimensiones_cm": [30, 20, 15]},
            "origen vacío": {"origen": "   "},
            "destino muy largo": {"destino": "x" * 201},
            "urgente no booleano": {"urgente": "no"},
            "seguro nulo": {"seguro": None},
            "fecha en el pasado": {"fecha_limite": "2020-01-01"},
            "fecha sin formato": {"fecha_limite": "20/11/2026"},
            "fecha imposible": {"fecha_limite": "2026-02-30"},
            "medio inexistente": {"medio": "submarino"},
            "tipo inexistente": {"tipo_servicio": "teletransporte"},
        }
        for nombre, cambios in casos.items():
            with self.subTest(nombre):
                self.assertError(self.registrar(cuerpo_valido(**cambios)), 400, "datos_invalidos")
        self.assertEqual(Pedido.objects.count(), 0)

    def test_fecha_limite_hoy_es_valida(self):
        hoy = timezone.localdate().isoformat()

        self.assertEqual(self.registrar(cuerpo_valido(fecha_limite=hoy)).status_code, 201)

    def test_peso_mayor_a_la_capacidad_responde_medio_no_apto(self):
        respuesta = self.registrar(cuerpo_valido(medio="dron", peso_kg=2.5, distancia_km=5))

        self.assertError(respuesta, 400, "medio_no_apto")

    def test_distancia_mayor_a_la_capacidad_responde_medio_no_apto(self):
        respuesta = self.registrar(cuerpo_valido(medio="dron", peso_kg=1, distancia_km=12))

        self.assertError(respuesta, 400, "medio_no_apto")


class CatalogoCaidoTests(BasePedidos):
    catalogo_caido = True

    def test_catalogo_caido_responde_503_y_no_crea_el_pedido(self):
        respuesta = self.registrar()

        self.assertError(respuesta, 503, "servicio_no_disponible")
        self.assertEqual(Pedido.objects.count(), 0)


class ConsultaTests(BasePedidos):

    def test_consultar_folio_existente_devuelve_datos_minimos(self):
        creado = self.registrar().json()
        respuesta = self.client.get(f"{URL}{creado['folio']}/")

        self.assertEqual(respuesta.status_code, 200)
        self.assertEqual(respuesta["Content-Type"], CONTENT_TYPE)
        datos = respuesta.json()
        self.assertEqual(
            set(datos),
            {
                "folio", "estado", "medio", "tipo_servicio", "fecha_creacion",
                "fecha_limite", "actualizado_en",
            },
        )
        self.assertEqual(datos["folio"], creado["folio"])
        self.assertEqual(datos["estado"], "CREADO")

    def test_folio_en_minusculas_tambien_se_encuentra(self):
        folio = self.registrar().json()["folio"]

        self.assertEqual(self.client.get(f"{URL}{folio.lower()}/").status_code, 200)

    def test_folio_inexistente_responde_404(self):
        respuesta = self.client.get(f"{URL}PQ-20261117-7KQ3/")

        self.assertError(respuesta, 404, "no_encontrado")

    def test_folio_con_formato_invalido_responde_400(self):
        self.assertError(self.client.get(f"{URL}ABC-123/"), 400, "datos_invalidos")


class EstadoTests(BasePedidos):

    def setUp(self):
        super().setUp()
        self.folio = self.registrar().json()["folio"]

    def test_transiciones_validas_hasta_entregado(self):
        respuesta = self.cambiar(self.folio, "EN_CAMINO")

        self.assertEqual(respuesta.status_code, 200)
        datos = respuesta.json()
        self.assertEqual(datos["estado_anterior"], "CREADO")
        self.assertEqual(datos["estado"], "EN_CAMINO")
        self.assertIn("actualizado_en", datos)
        self.assertNotIn("costo", datos)

        self.assertEqual(self.cambiar(self.folio, "ENTREGADO").json()["estado"], "ENTREGADO")
        self.assertEqual(self.client.get(f"{URL}{self.folio}/").json()["estado"], "ENTREGADO")

    def test_cancelar_desde_creado(self):
        respuesta = self.cambiar(self.folio, "CANCELADO")

        self.assertEqual(respuesta.status_code, 200)
        self.assertEqual(respuesta.json()["estado"], "CANCELADO")

    def test_transiciones_invalidas_responden_409(self):
        self.assertError(self.cambiar(self.folio, "ENTREGADO"), 409, "transicion_invalida")
        self.assertError(self.cambiar(self.folio, "CREADO"), 409, "transicion_invalida")

        self.cambiar(self.folio, "EN_CAMINO")
        self.assertError(self.cambiar(self.folio, "CANCELADO"), 409, "transicion_invalida")

        self.cambiar(self.folio, "ENTREGADO")
        self.assertError(self.cambiar(self.folio, "CANCELADO"), 409, "transicion_invalida")
        self.assertEqual(Pedido.objects.get().estado, "ENTREGADO")

    def test_estado_desconocido_o_faltante_responde_400(self):
        self.assertError(self.cambiar(self.folio, "PERDIDO"), 400, "datos_invalidos")
        respuesta = self.client.patch(
            f"{URL}{self.folio}/estado/", "{}", content_type=CONTENT_TYPE
        )
        self.assertError(respuesta, 400, "datos_invalidos")

    def test_cambiar_estado_de_folio_inexistente_responde_404(self):
        self.assertError(self.cambiar("PQ-20261117-7KQ3", "EN_CAMINO"), 404, "no_encontrado")


class RutasTests(BasePedidos):

    def test_metodo_no_soportado_responde_404(self):
        self.assertError(self.client.get(URL), 404, "ruta_no_encontrada")
        self.assertError(self.client.delete(f"{URL}PQ-20261117-7KQ3/"), 404, "ruta_no_encontrada")

    def test_ruta_inexistente_responde_404_en_json(self):
        respuesta = self.client.get(f"{URL}PQ-20261117-7KQ3/otra/")

        self.assertEqual(respuesta.status_code, 404)
        self.assertEqual(respuesta.json()["error"], "ruta_no_encontrada")


class ClienteCatalogoTests(SimpleTestCase):

    def _respuesta(self, datos):
        respuesta = mock.MagicMock()
        respuesta.read.return_value = json.dumps(datos).encode("utf-8")
        respuesta.__enter__.return_value = respuesta
        return respuesta

    @mock.patch("pedidos.cliente_catalogo.urllib.request.urlopen")
    def test_usa_url_interna_y_tiempo_limite(self, urlopen):
        urlopen.return_value = self._respuesta(MEDIOS["dron"])

        medio = ClienteCatalogo("http://catalogo:8000", timeout=3).obtener_medio("dron")

        self.assertEqual(medio["clave"], "dron")
        peticion = urlopen.call_args.args[0]
        self.assertEqual(peticion.full_url, "http://catalogo:8000/api/catalogo/medios/dron/")
        self.assertEqual(urlopen.call_args.kwargs["timeout"], 3)

    @mock.patch("pedidos.cliente_catalogo.urllib.request.urlopen")
    def test_404_devuelve_none(self, urlopen):
        urlopen.side_effect = urllib.error.HTTPError("u", 404, "Not Found", {}, None)

        self.assertIsNone(ClienteCatalogo("http://x").obtener_medio("submarino"))

    @mock.patch("pedidos.cliente_catalogo.urllib.request.urlopen")
    def test_tiempo_agotado_o_503_lanza_catalogo_no_disponible(self, urlopen):
        for error in (
            TimeoutError("timed out"),
            urllib.error.URLError("Name or service not known"),
            urllib.error.HTTPError("u", 503, "Unavailable", {}, None),
        ):
            with self.subTest(error=repr(error)):
                urlopen.side_effect = error
                with self.assertRaises(CatalogoNoDisponible):
                    ClienteCatalogo("http://x").obtener_medio("dron")

    @mock.patch("pedidos.cliente_catalogo.urllib.request.urlopen")
    def test_busca_el_tipo_de_servicio_en_la_lista(self, urlopen):
        urlopen.return_value = self._respuesta({"tipos_servicio": list(TIPOS.values())})

        cliente = ClienteCatalogo("http://x")
        self.assertEqual(cliente.obtener_tipo_servicio("express")["multiplicador_costo"], 1.5)
        self.assertIsNone(cliente.obtener_tipo_servicio("teletransporte"))


# ---------- catalogo caído o lento, con sockets reales (no se simula urlopen) ----------

class _ManejadorCatalogo(http.server.BaseHTTPRequestHandler):
    """Responde como catalogo según `modo` del servidor: ok, lento o cortado."""

    def do_GET(self):
        try:
            self._responder()
        except (BrokenPipeError, ConnectionResetError):
            pass  # El cliente ya se fue por tiempo límite: es lo que se prueba.

    def _responder(self):
        servidor = self.server
        if servidor.modo == "lento":
            time.sleep(servidor.espera)
        if self.path.startswith("/api/catalogo/medios/"):
            datos = MEDIOS.get(self.path.rstrip("/").rsplit("/", 1)[-1])
        else:
            datos = {"tipos_servicio": list(TIPOS.values())}
        cuerpo = json.dumps(datos).encode("utf-8")
        self.send_response(200 if datos else 404)
        self.send_header("Content-Type", "application/json")
        if servidor.modo == "cortado":
            # Anuncia más bytes de los que manda y cierra: la respuesta llega incompleta.
            self.send_header("Content-Length", str(len(cuerpo) + 100))
            self.end_headers()
            self.wfile.write(cuerpo[:5])
            return
        self.send_header("Content-Length", str(len(cuerpo)))
        self.end_headers()
        self.wfile.write(cuerpo)

    def log_message(self, *args):
        pass


class ServidorCatalogo:
    """catalogo de mentira en 127.0.0.1 con un puerto libre."""

    def __init__(self, modo="ok", espera=0):
        self.servidor = http.server.ThreadingHTTPServer(("127.0.0.1", 0), _ManejadorCatalogo)
        self.servidor.daemon_threads = True
        self.servidor.modo, self.servidor.espera = modo, espera
        self.url = f"http://127.0.0.1:{self.servidor.server_address[1]}"

    def __enter__(self):
        threading.Thread(target=self.servidor.serve_forever, daemon=True).start()
        return self

    def __exit__(self, *args):
        self.servidor.shutdown()
        self.servidor.server_close()


def url_sin_servidor():
    """URL de un puerto donde nadie escucha: conexión rechazada, como un servicio caído."""
    with socket.socket() as libre:
        libre.bind(("127.0.0.1", 0))
        puerto = libre.getsockname()[1]
    return f"http://127.0.0.1:{puerto}"


class ClienteCatalogoTiemposTests(SimpleTestCase):
    TIMEOUT = 0.5

    def assertNoDisponibleRapido(self, cliente):
        inicio = time.monotonic()
        with self.assertRaises(CatalogoNoDisponible):
            cliente.obtener_medio("motocicleta")
        self.assertLess(time.monotonic() - inicio, self.TIMEOUT + 0.5)

    def test_servicio_caido_lanza_catalogo_no_disponible(self):
        self.assertNoDisponibleRapido(ClienteCatalogo(url_sin_servidor(), timeout=self.TIMEOUT))

    def test_respuesta_lenta_se_corta_en_el_tiempo_limite(self):
        with ServidorCatalogo("lento", espera=3) as catalogo:
            self.assertNoDisponibleRapido(ClienteCatalogo(catalogo.url, timeout=self.TIMEOUT))

    def test_respuesta_incompleta_lanza_catalogo_no_disponible(self):
        with ServidorCatalogo("cortado") as catalogo:
            self.assertNoDisponibleRapido(ClienteCatalogo(catalogo.url, timeout=self.TIMEOUT))

    def test_dns_lento_no_pasa_del_tiempo_limite(self):
        # Con el contenedor de catalogo apagado, resolver su nombre tarda ~4 s y el
        # timeout de urlopen no cubre esa búsqueda.
        def dns_lento(*args, **kwargs):
            time.sleep(3)
            raise socket.gaierror("Name or service not known")

        with mock.patch("socket.getaddrinfo", dns_lento):
            self.assertNoDisponibleRapido(
                ClienteCatalogo("http://catalogo:8000", timeout=self.TIMEOUT))

    def test_servidor_rapido_sigue_respondiendo(self):
        with ServidorCatalogo("ok") as catalogo:
            cliente = ClienteCatalogo(catalogo.url, timeout=self.TIMEOUT)
            self.assertEqual(cliente.obtener_medio("dron")["clave"], "dron")
            self.assertEqual(cliente.obtener_tipo_servicio("express")["clave"], "express")


@override_settings(CATALOGO_TIMEOUT=0.5)
class RegistroConCatalogoRealTests(BasePedidos):
    """POST /api/pedidos/ de punta a punta, con catalogo por HTTP real."""

    def setUp(self):
        # Sin el CatalogoFalso de BasePedidos: se usa el ClienteCatalogo verdadero.
        pass

    def registrar_contra(self, url_catalogo):
        with self.settings(CATALOGO_URL=url_catalogo):
            inicio = time.monotonic()
            respuesta = self.registrar()
            return respuesta, time.monotonic() - inicio

    def test_catalogo_caido_responde_503_sin_crear_pedido(self):
        respuesta, duracion = self.registrar_contra(url_sin_servidor())

        self.assertError(respuesta, 503, "servicio_no_disponible")
        self.assertEqual(respuesta.json()["detalle"], "El servicio catalogo no respondió")
        self.assertEqual(Pedido.objects.count(), 0)
        self.assertLess(duracion, 1.5)

    def test_catalogo_lento_responde_503_en_el_tiempo_limite(self):
        with ServidorCatalogo("lento", espera=3) as catalogo:
            respuesta, duracion = self.registrar_contra(catalogo.url)

        self.assertError(respuesta, 503, "servicio_no_disponible")
        self.assertEqual(Pedido.objects.count(), 0)
        self.assertLess(duracion, 1.5)

    def test_catalogo_responde_y_el_pedido_se_crea(self):
        with ServidorCatalogo("ok") as catalogo:
            respuesta, _ = self.registrar_contra(catalogo.url)

        self.assertEqual(respuesta.status_code, 201, respuesta.content)
        self.assertEqual(Pedido.objects.count(), 1)
