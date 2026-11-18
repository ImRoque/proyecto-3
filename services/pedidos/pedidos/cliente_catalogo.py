"""Cliente HTTP del servicio catalogo.

pedidos nunca importa código de catalogo: le pregunta por HTTP interno con tiempo límite.
"""
import json
import urllib.error
import urllib.parse
import urllib.request

from django.conf import settings


class CatalogoNoDisponible(Exception):
    """catalogo no respondió a tiempo o respondió algo inesperado."""


class ClienteCatalogo:

    def __init__(self, url_base=None, timeout=None):
        self.url_base = (url_base or settings.CATALOGO_URL).rstrip("/")
        self.timeout = timeout if timeout is not None else settings.CATALOGO_TIMEOUT

    def _get(self, ruta):
        """GET a catalogo. Devuelve el JSON, o None si respondió 404."""
        url = f"{self.url_base}/api/catalogo/{ruta}"
        peticion = urllib.request.Request(url, headers={"Accept": "application/json"})
        try:
            with urllib.request.urlopen(peticion, timeout=self.timeout) as respuesta:
                return json.loads(respuesta.read().decode("utf-8"))
        except urllib.error.HTTPError as error:
            if error.code == 404:
                return None
            raise CatalogoNoDisponible(f"catalogo respondió {error.code}") from error
        except (urllib.error.URLError, TimeoutError, OSError, ValueError) as error:
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
