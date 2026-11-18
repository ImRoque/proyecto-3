"""Capa de acceso a datos del catálogo (patrón Repository).

Las vistas solo hablan con estas clases y reciben diccionarios con los campos exactos del
contrato de docs/api.md. Así el ORM, la búsqueda y la forma del JSON quedan en un solo lugar
y las vistas no dependen de cómo se guardan los datos.
"""
import unicodedata

from .models import MedioEntrega, TipoServicio


def normalizar(texto):
    """Pasa a minúsculas y quita acentos para comparar sin distinguirlos."""
    descompuesto = unicodedata.normalize("NFKD", texto.casefold())
    return "".join(c for c in descompuesto if not unicodedata.combining(c))


class MedioRepositorio:
    """Consulta los medios de entrega."""

    @staticmethod
    def _a_dict(medio):
        return {
            "clave": medio.clave,
            "nombre": medio.nombre,
            "descripcion": medio.descripcion,
            "peso_max_kg": medio.peso_max_kg,
            "distancia_max_km": medio.distancia_max_km,
            "velocidad_kmh": medio.velocidad_kmh,
            "costo_base": medio.costo_base,
            "costo_por_km": medio.costo_por_km,
        }

    def listar(self, q=None):
        """Devuelve los medios; si hay `q`, solo los que lo contienen en nombre o descripción.

        La búsqueda ignora mayúsculas y acentos. Se filtra en Python porque el catálogo es
        pequeño y así funciona igual en SQLite y PostgreSQL sin la extensión unaccent.
        """
        medios = MedioEntrega.objects.all()
        if q:
            buscado = normalizar(q)
            medios = [
                m for m in medios
                if buscado in normalizar(m.nombre) or buscado in normalizar(m.descripcion)
            ]
        return [self._a_dict(m) for m in medios]

    def obtener(self, clave):
        """Devuelve el medio con esa clave, o None si no existe."""
        medio = MedioEntrega.objects.filter(clave=clave).first()
        return self._a_dict(medio) if medio else None


class TipoServicioRepositorio:
    """Consulta los tipos de servicio."""

    @staticmethod
    def _a_dict(tipo):
        return {
            "clave": tipo.clave,
            "nombre": tipo.nombre,
            "descripcion": tipo.descripcion,
            "tiempo_max_horas": tipo.tiempo_max_horas,
            "multiplicador_costo": tipo.multiplicador_costo,
        }

    def listar(self):
        return [self._a_dict(t) for t in TipoServicio.objects.all()]
