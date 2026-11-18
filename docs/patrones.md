# Análisis de patrones (web y móvil)

> **Estado:** PENDIENTE
> Se completa cuando exista código. Cada patrón debe señalar dónde aparece en el
> repositorio o explicar por qué no aplica. No se registran patrones por adelantado.

## Patrones a analizar

Lista de referencia del enunciado del curso. Que aparezca aquí no significa que se haya decidido usarlo.

| Patrón | ¿Aplica? | Dónde (archivo / clase / función) | Qué problema resuelve | Autor del análisis |
|---|---|---|---|---|
| Strategy | | | | |
| Adapter | | | | |
| Facade | | | | |
| Repository | Sí | `services/catalogo/catalogo/repositorio.py`: clases `MedioRepositorio` y `TipoServicioRepositorio`, usadas por `services/catalogo/catalogo/views.py` | Las vistas no usan el ORM: piden datos al repositorio y reciben diccionarios con los campos exactos de `docs/api.md`. La consulta, la búsqueda sin mayúsculas ni acentos y la forma del JSON quedan en un solo lugar; si cambia el almacenamiento (SQLite, PostgreSQL) o la búsqueda, las vistas no cambian. | Int. 2 |
| Gateway / BFF | | | | |
| Observer | | | | |
| Front Controller | | | | |
| MVC | | | | |

## Servidor vs cliente

<!-- Contraste entre el diseño del servidor y el del cliente Flutter -->

## Web vs móvil

| Aspecto | Igual | Cambia |
|---|---|---|
| Código Flutter | | |
| URL base | | |
| Empaquetado | | |
| Restricciones de plataforma | | |

## Conclusiones del equipo
