# Contratos de API

> **Estado:** PENDIENTE DE ACUERDO DEL EQUIPO
> Ninguna ruta, formato ni código de respuesta de este archivo es definitivo hasta que
> el equipo lo apruebe por PR. Cualquier cambio posterior también debe entrar por PR.

## Convenciones generales (por acordar)

> **Estado de esta sección:** Propuesto (Int. 1, coordinación). Pendiente de aprobación
> del equipo por PR. Las rutas de negocio de cada servicio las proponen sus responsables.

| Tema | Acuerdo | Estado |
|---|---|---|
| URL base para clientes | Los clientes solo usan el API Gateway, publicado en el puerto `8080` del equipo anfitrión. Web: `http://localhost:8080`. Emulador Android: `http://10.0.2.2:8080`. Teléfono físico: `http://<IP-de-la-PC>:8080`. Flutter la recibe con `--dart-define=API_URL=...`. | Propuesto |
| Prefijo de rutas por servicio | Cada servicio tiene un prefijo fijo: `/api/catalogo/`, `/api/pedidos/`, `/api/recomendar/`, `/api/asistente/`. El gateway enruta por prefijo y conserva la ruta completa. Todas las rutas terminan en `/`. | Propuesto |
| Ruta de salud | Cada servicio expone `GET /api/<servicio>/health/`, que responde `200` con `{"servicio": "<servicio>", "ok": true}`. No consulta otros servicios. | Propuesto |
| Formato de datos | JSON en UTF-8, en solicitudes y respuestas. Encabezado `Content-Type: application/json; charset=utf-8`. Fechas en ISO 8601 (`2026-11-17` o `2026-11-17T10:30:00-06:00`). | Propuesto |
| Formato de errores | Formato único para todos los servicios y el gateway: `{"error": "<codigo>", "detalle": "<texto opcional>"}`. Ver [Códigos de error](#códigos-de-error). | Propuesto |
| Códigos HTTP | Solo `200`, `201`, `400`, `404`, `409` y `503`. Ver [Códigos HTTP](#códigos-http). | Propuesto |
| Versionado | Sin versión en la ruta durante el proyecto. Un cambio incompatible se acuerda por PR en este archivo y se avisa al responsable de Flutter. | Propuesto |
| Nombres de campos | `snake_case` en español y sin acentos, por ejemplo `peso_kg`, `distancia_km`, `fecha_limite`. Valores fijos (estados, intenciones) en `MAYUSCULAS` o minúsculas según lo defina cada contrato, siempre sin acentos. | Propuesto |
| Folio | Lo genera **únicamente** el servicio `pedidos` al registrar un pedido. Formato: `PQ-AAAAMMDD-XXXX` (ej. `PQ-20261117-7KQ3`), donde `AAAAMMDD` es la fecha de creación y `XXXX` son 4 caracteres aleatorios de `A-Z` y `2-9` sin `O`, `I`, `0` ni `1`. La unicidad la garantiza la base de datos de `pedidos`; si choca, se genera otro. Formato por confirmar con Int. 2. | Propuesto |

### Códigos HTTP

| Código | Cuándo se usa |
|---|---|
| `200` OK | Consulta o acción exitosa que no crea un recurso nuevo (leer catálogo, consultar pedido, obtener recomendación, respuesta del asistente, salud). |
| `201` Created | Se creó un recurso nuevo (por ejemplo, registrar un pedido). |
| `400` Bad Request | La solicitud no es JSON válido, falta un campo obligatorio o un valor no cumple las reglas (peso negativo, tipo incorrecto). |
| `404` Not Found | El recurso no existe (folio inexistente) o la ruta no existe. |
| `409` Conflict | La solicitud es válida pero contradice el estado actual (transición de estado no permitida, como cancelar un pedido `ENTREGADO`). |
| `503` Service Unavailable | Un servicio necesario no responde o superó el tiempo límite. Lo devuelve el gateway cuando el servicio destino está caído, o un servicio cuando otro del que depende no responde. |

Un `500` no se usa de forma intencional: si aparece, es un error que se debe corregir.

### Códigos de error

Valores base del campo `error`. Cada servicio puede proponer códigos más específicos en su
contrato, siempre en `snake_case` y sin acentos.

| HTTP | `error` | Ejemplo de `detalle` |
|---|---|---|
| `400` | `datos_invalidos` | `"peso_kg debe ser mayor que 0"` |
| `404` | `no_encontrado` | `"No existe el pedido con folio PQ-20261117-7KQ3"` |
| `404` | `ruta_no_encontrada` | `"La ruta solicitada no existe"` |
| `409` | `conflicto` | `"Un pedido ENTREGADO no se puede cancelar"` |
| `503` | `servicio_no_disponible` | `"El servicio recomendar no respondió"` |

## Plantilla por endpoint

Copia este bloque por cada endpoint propuesto.

### <Nombre de la operación>

| Campo | Valor |
|---|---|
| Servicio | |
| Método | |
| Ruta | |
| Responsable | |
| Estado | Propuesto / Aprobado |

**Solicitud**

```
<!-- ejemplo de cuerpo o parámetros -->
```

**Respuesta exitosa**

```
<!-- ejemplo -->
```

**Errores**

| Código | Cuándo ocurre |
|---|---|
| | |

**Consumido por:** <!-- app_flutter, otro servicio, ... -->

---

## Operaciones que el alcance mínimo debe cubrir

Lista de referencia del enunciado. Cada una necesita un contrato aprobado:

- [ ] Explorar y buscar en el catálogo
- [ ] Obtener una recomendación
- [ ] Registrar un pedido
- [ ] Consultar un pedido por folio
- [ ] Conversar con el asistente
