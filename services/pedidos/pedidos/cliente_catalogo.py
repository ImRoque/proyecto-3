"""Cliente HTTP del servicio catalogo.

pedidos nunca importa código de catalogo: le pregunta por HTTP interno con tiempo límite.
"""
import http.client
import json
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import TimeoutError as TiempoAgotado

from django.conf import settings

# El timeout de urlopen no cubre la búsqueda DNS: con el contenedor de catalogo apagado,
# resolver su nombre tarda ~4 s. Cada llamada corre en un hilo y se espera como máximo
# `timeout` segundos en total; si se agota, el hilo termina solo en segundo plano.
_HILOS = ThreadPoolExecutor(max_workers=8, thread_name_prefix="cliente-catalogo")


class CatalogoNoDisponible(Exception):
    """catalogo no respondió a tiempo o respondió algo inesperado."""


class ClienteCatalogo:

    def __init__(self, url_base=None, timeout=None):
        self.url_base = (url_base or settings.CATALOGO_URL).rstrip("/")
        self.timeout = timeout if timeout is not None else settings.CATALOGO_TIMEOUT

    def _get(self, ruta):
        """GET a catalogo. Devuelve el JSON, o None si respondió 404.

        El tiempo total (DNS, conexión y lectura) no pasa de `self.timeout` segundos.
        """
        url = f"{self.url_base}/api/catalogo/{ruta}"
        peticion = urllib.request.Request(url, headers={"Accept": "application/json"})
        futuro = _HILOS.submit(self._enviar, peticion)
        try:
            return futuro.result(timeout=self.timeout)
        except TiempoAgotado as error:
            futuro.cancel()
            raise CatalogoNoDisponible(f"no respondió en {self.timeout:g} s") from error

    def _enviar(self, peticion):
        try:
            with urllib.request.urlopen(peticion, timeout=self.timeout) as respuesta:
                return json.loads(respuesta.read().decode("utf-8"))
        except urllib.error.HTTPError as error:
            if error.code == 404:
                return None
            raise CatalogoNoDisponible(f"catalogo respondió {error.code}") from error
        except (urllib.error.URLError, http.client.HTTPException, TimeoutError, OSError,
                ValueError) as error:
            # HTTPException cubre respuestas cortadas (IncompleteRead) o mal formadas.
            raise CatalogoNoDisponible(str(error)) from error

    def obtener_medio(self, clave):
        """Medio con esa clave, o None si no existe."""
        return self._get(f"medios/{urllib.parse.quote(clave, safe='')}/")

    def obtener_tipo_servicio(self, clave):
        """Tipo de servicio con esa clave, o None si no existe."""
        datos = self._get("tipos-servicio/")
        if not isinstance(datos, dict) or "tipos_servicio" not in datos:
            raise CatalogoNoDisponible("catalogo respondió un formato inesperado")
        return next((t for t in datos["tipos_servicio"] if t.get("clave") == clave), None)
