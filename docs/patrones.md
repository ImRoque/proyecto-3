# Análisis de patrones (web y móvil)

> **Estado:** PENDIENTE
> Se completa cuando exista código. Cada patrón debe señalar dónde aparece en el
> repositorio o explicar por qué no aplica. No se registran patrones por adelantado.

## Patrones a analizar

Lista de referencia del enunciado del curso. Que aparezca aquí no significa que se haya decidido usarlo.

| Patrón | ¿Aplica? | Dónde (archivo / clase / función) | Qué problema resuelve | Autor del análisis |
|---|---|---|---|---|
| Strategy | Sí | `services/recomendar/recomendar/reglas.py`: interfaz `Regla` (método `descarta(envio, medio)`) con las estrategias `ReglaPesoMaximo`, `ReglaDistanciaMaxima`, `ReglaTamanoPaquete` y `ReglaUrgencia`, reunidas en la tupla `REGLAS`; las usa `recomendar()` en `services/recomendar/recomendar/recomendacion.py` | Hay cuatro reglas de negocio (R1 a R4 de `docs/api.md`) que pueden corregir al modelo, y cada una revisa algo distinto. Con la misma interfaz, `recomendar()` las aplica en orden sin saber qué revisa cada una: toma el motivo de la primera que descarta un medio. Agregar, quitar o reordenar una regla solo cambia `REGLAS`, y cada regla se prueba por separado. | Int. 3 |
| Adapter | | | | |
| Facade | Sí | `services/pedidos/pedidos/confirmacion.py`: clase `ConfirmacionPedido`, usada por `registrar` en `services/pedidos/pedidos/views.py` | Registrar un pedido requiere varios pasos: validar el cuerpo y la `Idempotency-Key`, revisar si la clave ya se usó, consultar `catalogo` por HTTP, calcular el costo y guardar (resolviendo la carrera de dos peticiones con la misma clave). La vista solo llama a `confirmar()` y recibe el pedido y el código HTTP; el orden de los pasos y el manejo de errores quedan en una sola clase que se prueba sin HTTP. | Int. 2 |
| Repository | Sí | `services/catalogo/catalogo/repositorio.py`: clases `MedioRepositorio` y `TipoServicioRepositorio`, usadas por `services/catalogo/catalogo/views.py` | Las vistas no usan el ORM: piden datos al repositorio y reciben diccionarios con los campos exactos de `docs/api.md`. La consulta, la búsqueda sin mayúsculas ni acentos y la forma del JSON quedan en un solo lugar; si cambia el almacenamiento (SQLite, PostgreSQL) o la búsqueda, las vistas no cambian. | Int. 2 |
| Repository | Sí | `services/pedidos/pedidos/repositorio.py`: clase `PedidoRepositorio`, usada por `ConfirmacionPedido` y por `services/pedidos/pedidos/views.py` | Ni las vistas ni la confirmación usan el ORM. El repositorio encapsula la creación con folio único (reintenta si choca), la detección de una `Idempotency-Key` repetida por la restricción única, el bloqueo de la fila al cambiar el estado y las dos formas del JSON del contrato (completa al registrar, mínima al consultar). | Int. 2 |
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
