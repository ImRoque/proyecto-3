"""Clientes HTTP de pedidos y recomendar.

asistente nunca importa código de otro servicio ni lee su base de datos: les pregunta por
HTTP interno (nombres de Docker tomados de variables de entorno) con tiempo límite.
"""
import json
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import TimeoutError as TiempoAgotado

from django.conf import settings

# El timeout de urlopen no cubre la búsqueda DNS: con un contenedor apagado, resolver su
# nombre tarda ~4 s. Cada llamada corre en un hilo y se espera como máximo `timeout`
# segundos en total; si se agota, el hilo termina solo en segundo plano.
_HILOS = ThreadPoolExecutor(max_workers=8, thread_name_prefix="cliente-http")


class ServicioNoDisponible(Exception):
    """El servicio no respondió a tiempo, está caído o respondió algo inesperado."""

    def __init__(self, servicio, detalle):
        super().__init__(f"{servicio}: {detalle}")
        self.servicio = servicio


class SolicitudRechazada(Exception):
    """El servicio respondió 400 con el formato de error de docs/api.md."""

    def __init__(self, codigo, detalle):
        super().__init__(f"{codigo}: {detalle}")
        self.codigo = codigo
        self.detalle = detalle


class _ClienteHttp:
    servicio = ""

    def __init__(self, url_base, timeout=None):
        self.url_base = url_base.rstrip("/")
        self.timeout = timeout if timeout is not None else settings.SERVICIOS_TIMEOUT

    def _pedir(self, metodo, ruta, cuerpo=None):
        """Devuelve (status, json). Lanza ServicioNoDisponible si no hay respuesta útil.

        El tiempo total (DNS, conexión y lectura) no pasa de `self.timeout` segundos.
        """
        datos = json.dumps(cuerpo).encode("utf-8") if cuerpo is not None else None
        peticion = urllib.request.Request(
            f"{self.url_base}{ruta}", data=datos, method=metodo,
            headers={"Accept": "application/json", "Content-Type": "application/json"},
        )
        futuro = _HILOS.submit(self._enviar, peticion)
        try:
            return futuro.result(timeout=self.timeout)
        except TiempoAgotado as error:
            futuro.cancel()
            raise ServicioNoDisponible(
                self.servicio, f"no respondió en {self.timeout:g} s") from error

    def _enviar(self, peticion):
        try:
            with urllib.request.urlopen(peticion, timeout=self.timeout) as respuesta:
                return respuesta.status, self._leer(respuesta)
        except urllib.error.HTTPError as error:
            if error.code >= 500:
                raise ServicioNoDisponible(self.servicio, f"respondió {error.code}") from error
            return error.code, self._leer(error)
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            raise ServicioNoDisponible(self.servicio, str(error)) from error

    def _leer(self, respuesta):
        try:
            return json.loads(respuesta.read().decode("utf-8"))
        except (UnicodeDecodeError, ValueError) as error:
            raise ServicioNoDisponible(self.servicio, "respondió algo que no es JSON") from error


class ClientePedidos(_ClienteHttp):
    servicio = "pedidos"

    def __init__(self, url_base=None, timeout=None):
        super().__init__(url_base or settings.PEDIDOS_URL, timeout)

    def consultar(self, folio):
        """Datos mínimos del pedido, o None si no existe. GET /api/pedidos/<folio>/."""
        status, datos = self._pedir("GET", f"/api/pedidos/{urllib.parse.quote(folio)}/")
        if status == 200 and isinstance(datos, dict):
            return datos
        if status in (400, 404):
            return None
        raise ServicioNoDisponible(self.servicio, f"respondió {status}")


class ClienteRecomendar(_ClienteHttp):
    servicio = "recomendar"

    def __init__(self, url_base=None, timeout=None):
        super().__init__(url_base or settings.RECOMENDAR_URL, timeout)

    def recomendar(self, peso_kg, distancia_km, urgente, dimensiones_cm):
        """Respuesta de POST /api/recomendar/. Lanza SolicitudRechazada si responde 400."""
        status, datos = self._pedir("POST", "/api/recomendar/", {
            "peso_kg": peso_kg,
            "distancia_km": distancia_km,
            "urgente": urgente,
            "dimensiones_cm": dimensiones_cm,
        })
        if status == 200 and isinstance(datos, dict):
            return datos
        if status == 400 and isinstance(datos, dict):
            raise SolicitudRechazada(datos.get("error", ""), datos.get("detalle", ""))
        raise ServicioNoDisponible(self.servicio, f"respondió {status}")
