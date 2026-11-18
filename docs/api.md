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

## Catálogo

> **Estado de esta sección:** Propuesto (Int. 2). Los valores numéricos de los ejemplos
> (pesos, distancias, costos, horas) son ilustrativos; los definitivos se cargan como datos
> de prueba en `services/catalogo/`.

**Medio de entrega.** Campos que devuelve el catálogo:

| Campo | Tipo | Descripción |
|---|---|---|
| `clave` | texto | Identificador fijo: `camioneta`, `motocicleta`, `bicicleta` o `dron`. |
| `nombre` | texto | Nombre para mostrar. |
| `descripcion` | texto | Descripción corta. |
| `peso_max_kg` | número | Peso máximo que puede llevar. |
| `distancia_max_km` | número | Distancia máxima que puede recorrer. |
| `velocidad_kmh` | número | Velocidad promedio. |
| `costo_base` | número | Costo fijo por envío, en MXN. |
| `costo_por_km` | número | Costo por kilómetro, en MXN. |

**Tipo de servicio.** Campos que devuelve el catálogo:

| Campo | Tipo | Descripción |
|---|---|---|
| `clave` | texto | Identificador fijo: `estandar`, `express` o `mismo_dia`. |
| `nombre` | texto | Nombre para mostrar. |
| `descripcion` | texto | Descripción corta. |
| `tiempo_max_horas` | entero | Tiempo máximo de entrega comprometido. |
| `multiplicador_costo` | número | Factor que se aplica al costo del medio. |

### Listar medios de entrega

| Campo | Valor |
|---|---|
| Servicio | catalogo |
| Método | `GET` |
| Ruta | `/api/catalogo/medios/` |
| Responsable | Int. 2 |
| Estado | Propuesto |

**Solicitud**

Parámetro opcional `q`: texto a buscar en `nombre` y `descripcion`, sin distinguir
mayúsculas ni acentos. Sin `q` devuelve todos los medios.

```
GET /api/catalogo/medios/?q=moto
```

**Respuesta exitosa** (`200`)

```json
{
  "medios": [
    {
      "clave": "motocicleta",
      "nombre": "Motocicleta",
      "descripcion": "Entregas rápidas en ciudad",
      "peso_max_kg": 20,
      "distancia_max_km": 40,
      "velocidad_kmh": 35,
      "costo_base": 40.0,
      "costo_por_km": 4.5
    }
  ],
  "total": 1
}
```

Si ningún medio coincide, responde `200` con `"medios": []` y `"total": 0`.

**Errores**

| Código | `error` | Cuándo ocurre |
|---|---|---|
| `400` | `datos_invalidos` | `q` tiene más de 100 caracteres. |
| `503` | `servicio_no_disponible` | El servicio `catalogo` no responde (lo devuelve el gateway). |

**Consumido por:** app_flutter (pantalla de catálogo y búsqueda).

### Detalle de un medio de entrega

| Campo | Valor |
|---|---|
| Servicio | catalogo |
| Método | `GET` |
| Ruta | `/api/catalogo/medios/<clave>/` |
| Responsable | Int. 2 |
| Estado | Propuesto |

**Solicitud**

```
GET /api/catalogo/medios/dron/
```

**Respuesta exitosa** (`200`)

```json
{
  "clave": "dron",
  "nombre": "Dron",
  "descripcion": "Paquetes ligeros en distancias cortas",
  "peso_max_kg": 2,
  "distancia_max_km": 10,
  "velocidad_kmh": 60,
  "costo_base": 80.0,
  "costo_por_km": 6.0
}
```

**Errores**

| Código | `error` | Cuándo ocurre |
|---|---|---|
| `404` | `no_encontrado` | No existe un medio con esa `clave`. |
| `503` | `servicio_no_disponible` | El servicio `catalogo` no responde (lo devuelve el gateway). |

**Consumido por:** app_flutter (pantalla de detalle) y el servicio `pedidos` (validar el medio
y calcular el costo al registrar un pedido).

### Listar tipos de servicio

| Campo | Valor |
|---|---|
| Servicio | catalogo |
| Método | `GET` |
| Ruta | `/api/catalogo/tipos-servicio/` |
| Responsable | Int. 2 |
| Estado | Propuesto |

**Solicitud**

Sin parámetros.

```
GET /api/catalogo/tipos-servicio/
```

**Respuesta exitosa** (`200`)

```json
{
  "tipos_servicio": [
    {
      "clave": "estandar",
      "nombre": "Estándar",
      "descripcion": "Entrega en hasta 3 días",
      "tiempo_max_horas": 72,
      "multiplicador_costo": 1.0
    },
    {
      "clave": "express",
      "nombre": "Express",
      "descripcion": "Entrega en hasta 24 horas",
      "tiempo_max_horas": 24,
      "multiplicador_costo": 1.5
    },
    {
      "clave": "mismo_dia",
      "nombre": "Mismo día",
      "descripcion": "Entrega el mismo día",
      "tiempo_max_horas": 12,
      "multiplicador_costo": 2.0
    }
  ],
  "total": 3
}
```

**Errores**

| Código | `error` | Cuándo ocurre |
|---|---|---|
| `503` | `servicio_no_disponible` | El servicio `catalogo` no responde (lo devuelve el gateway). |

**Consumido por:** app_flutter (formulario de pedido) y el servicio `pedidos` (validar el tipo
y calcular el costo).

---

## Pedidos

> **Estado de esta sección:** Propuesto (Int. 2). No hay autenticación (fuera de alcance),
> por lo que cualquiera que conozca un folio puede consultarlo o cambiar su estado. Por eso
> la consulta devuelve solo datos mínimos.

**Estados y transiciones válidas**

| Estado actual | Puede pasar a |
|---|---|
| `CREADO` | `EN_CAMINO`, `CANCELADO` |
| `EN_CAMINO` | `ENTREGADO` |
| `ENTREGADO` | ninguno (final) |
| `CANCELADO` | ninguno (final) |

**Cálculo del costo (lo hace siempre el servidor).** `pedidos` consulta al servicio `catalogo`
por HTTP interno (`http://catalogo:8000/api/catalogo/...`) con tiempo límite y aplica:

```
costo = (costo_base + costo_por_km * distancia_km) * multiplicador_costo
        + 10 % de ese subtotal si seguro = true
```

El costo se guarda en el pedido al crearlo; si después cambia el catálogo, el pedido no cambia.
Se redondea a 2 decimales y la moneda es MXN.

### Registrar un pedido

| Campo | Valor |
|---|---|
| Servicio | pedidos |
| Método | `POST` |
| Ruta | `/api/pedidos/` |
| Responsable | Int. 2 |
| Estado | Propuesto |

**Solicitud**

Encabezados:

| Encabezado | Obligatorio | Valor |
|---|---|---|
| `Content-Type` | Sí | `application/json; charset=utf-8` |
| `Idempotency-Key` | Sí | UUID v4 generado por el cliente. |

```
POST /api/pedidos/
Idempotency-Key: 3f6c2a1e-8b7d-4c1a-9e2f-5a4b3c2d1e0f
```

```json
{
  "origen": "Av. Juárez 100, Centro, Guadalajara",
  "destino": "Calle Hidalgo 25, Zapopan",
  "distancia_km": 8.5,
  "peso_kg": 2.3,
  "dimensiones_cm": {"largo": 30, "ancho": 20, "alto": 15},
  "urgente": false,
  "seguro": true,
  "fecha_limite": "2026-11-20",
  "medio": "motocicleta",
  "tipo_servicio": "express"
}
```

Reglas de validación (las aplica el servidor):

- Todos los campos son obligatorios.
- `origen` y `destino`: texto no vacío de máximo 200 caracteres.
- `distancia_km`, `peso_kg` y cada medida de `dimensiones_cm`: números mayores que 0.
- `fecha_limite`: fecha ISO 8601 igual o posterior a hoy.
- `medio` y `tipo_servicio`: claves existentes en el catálogo.
- `peso_kg` no puede superar `peso_max_kg` del medio y `distancia_km` no puede superar
  `distancia_max_km`.

**Evitar duplicados por doble clic (`Idempotency-Key`)**

- Flutter genera un UUID nuevo al abrir el formulario y lo reutiliza en todos los reintentos
  y clics de ese mismo envío. Solo genera otro cuando el pedido se registró y el usuario
  inicia un formulario nuevo.
- `pedidos` guarda la clave junto al pedido, con restricción de unicidad en la base de datos.
- Primera vez que llega la clave: crea el pedido y responde `201`.
- La clave se repite **con el mismo cuerpo**: no crea otro pedido; responde `200` con el
  mismo cuerpo del pedido creado la primera vez (mismo folio).
- La clave se repite **con un cuerpo distinto**: responde `409` con
  `idempotency_key_reutilizada` y no crea nada.

**Respuesta exitosa** (`201`, o `200` si la clave ya se había usado con el mismo cuerpo)

```json
{
  "folio": "PQ-20261117-7KQ3",
  "estado": "CREADO",
  "origen": "Av. Juárez 100, Centro, Guadalajara",
  "destino": "Calle Hidalgo 25, Zapopan",
  "distancia_km": 8.5,
  "peso_kg": 2.3,
  "dimensiones_cm": {"largo": 30, "ancho": 20, "alto": 15},
  "urgente": false,
  "seguro": true,
  "fecha_limite": "2026-11-20",
  "medio": "motocicleta",
  "tipo_servicio": "express",
  "costo": 129.11,
  "moneda": "MXN",
  "fecha_creacion": "2026-11-17T10:30:00-06:00"
}
```

**Errores**

| Código | `error` | Cuándo ocurre |
|---|---|---|
| `400` | `falta_idempotency_key` | No viene el encabezado `Idempotency-Key` o no es un UUID válido. |
| `400` | `datos_invalidos` | El cuerpo no es JSON válido, falta un campo o un valor no cumple las reglas (incluye `medio` o `tipo_servicio` inexistentes). |
| `400` | `medio_no_apto` | `peso_kg` o `distancia_km` superan la capacidad del medio elegido. |
| `409` | `idempotency_key_reutilizada` | La clave ya se usó con un cuerpo distinto. |
| `503` | `servicio_no_disponible` | `pedidos` no responde (gateway) o `catalogo` no respondió a tiempo; el pedido no se crea. |

**Consumido por:** app_flutter (formulario de pedido).

### Consultar un pedido por folio

| Campo | Valor |
|---|---|
| Servicio | pedidos |
| Método | `GET` |
| Ruta | `/api/pedidos/<folio>/` |
| Responsable | Int. 2 |
| Estado | Propuesto |

**Solicitud**

El folio se acepta en mayúsculas o minúsculas.

```
GET /api/pedidos/PQ-20261117-7KQ3/
```

**Respuesta exitosa** (`200`)

Solo datos mínimos para rastrear. No incluye `origen`, `destino`, peso, dimensiones, seguro
ni costo.

```json
{
  "folio": "PQ-20261117-7KQ3",
  "estado": "EN_CAMINO",
  "medio": "motocicleta",
  "tipo_servicio": "express",
  "fecha_creacion": "2026-11-17T10:30:00-06:00",
  "fecha_limite": "2026-11-20",
  "actualizado_en": "2026-11-17T12:05:00-06:00"
}
```

**Errores**

| Código | `error` | Cuándo ocurre |
|---|---|---|
| `400` | `datos_invalidos` | El folio no cumple el formato `PQ-AAAAMMDD-XXXX`. |
| `404` | `no_encontrado` | No existe un pedido con ese folio. |
| `503` | `servicio_no_disponible` | El servicio `pedidos` no responde (lo devuelve el gateway). |

**Consumido por:** app_flutter (pantalla de rastreo) y el servicio `asistente` (intención
`rastrear`).

### Cambiar el estado de un pedido

| Campo | Valor |
|---|---|
| Servicio | pedidos |
| Método | `PATCH` |
| Ruta | `/api/pedidos/<folio>/estado/` |
| Responsable | Int. 2 |
| Estado | Propuesto |

**Solicitud**

```
PATCH /api/pedidos/PQ-20261117-7KQ3/estado/
```

```json
{
  "estado": "EN_CAMINO"
}
```

**Respuesta exitosa** (`200`)

Mismos datos mínimos que la consulta por folio, más el estado anterior.

```json
{
  "folio": "PQ-20261117-7KQ3",
  "estado_anterior": "CREADO",
  "estado": "EN_CAMINO",
  "medio": "motocicleta",
  "tipo_servicio": "express",
  "fecha_creacion": "2026-11-17T10:30:00-06:00",
  "fecha_limite": "2026-11-20",
  "actualizado_en": "2026-11-17T12:05:00-06:00"
}
```

**Errores**

| Código | `error` | Cuándo ocurre |
|---|---|---|
| `400` | `datos_invalidos` | El cuerpo no es JSON válido, falta `estado`, el valor no es un estado conocido o el folio no cumple el formato. |
| `404` | `no_encontrado` | No existe un pedido con ese folio. |
| `409` | `transicion_invalida` | La transición no está en la tabla de transiciones válidas (por ejemplo `ENTREGADO → CANCELADO` o `CREADO → ENTREGADO`), incluido pedir el mismo estado que ya tiene. |
| `503` | `servicio_no_disponible` | El servicio `pedidos` no responde (lo devuelve el gateway). |

**Consumido por:** app_flutter (cancelar un pedido y, para la demostración, avanzar su estado).

---

## Recomendar

> **Estado de esta sección:** Propuesto (Int. 3). El modelo se entrena con un script aparte
> y el servicio solo carga el artefacto `.joblib`; nunca entrena dentro de una petición.

### Obtener recomendación

| Campo | Valor |
|---|---|
| Servicio | recomendar |
| Método | `POST` |
| Ruta | `/api/recomendar/` |
| Responsable | Int. 3 |
| Estado | Propuesto |

**Solicitud**

```
POST /api/recomendar/
```

```json
{
  "peso_kg": 3.5,
  "distancia_km": 6.0,
  "urgente": false,
  "dimensiones_cm": {"largo": 30, "ancho": 20, "alto": 15}
}
```

Reglas de validación:

- Todos los campos son obligatorios.
- `peso_kg`, `distancia_km` y cada medida de `dimensiones_cm`: números mayores que 0.
- `urgente`: booleano (`true` o `false`).

**Respuesta exitosa** (`200`)

```json
{
  "medio_modelo": "dron",
  "confianza": 0.62,
  "medio_final": "motocicleta",
  "corregido_por_reglas": true,
  "motivo": "El dron no lleva más de 2 kg; se eligió el siguiente medio apto según el modelo.",
  "alternativas": [
    {"medio": "bicicleta", "confianza": 0.08},
    {"medio": "camioneta", "confianza": 0.05}
  ]
}
```

| Campo | Descripción |
|---|---|
| `medio_modelo` | Clase que propuso el modelo (la de mayor probabilidad). |
| `confianza` | Probabilidad que el modelo asignó a `medio_modelo`, de 0 a 1. |
| `medio_final` | Medio recomendado después de aplicar las reglas de negocio. |
| `corregido_por_reglas` | `true` si una regla descartó a `medio_modelo` y `medio_final` es distinto. |
| `motivo` | Texto corto que explica la decisión. Si hubo corrección, nombra la regla. |
| `alternativas` | Otros medios que cumplen las reglas, sin `medio_final`, ordenados por la probabilidad del modelo (`confianza`). Puede ser una lista vacía. |

Los valores de `medio_modelo`, `medio_final` y `alternativas[].medio` son las claves del
catálogo: `camioneta`, `motocicleta`, `bicicleta` o `dron`.

**Errores**

| Código | `error` | Cuándo ocurre |
|---|---|---|
| `400` | `datos_invalidos` | El cuerpo no es JSON válido, falta un campo o un valor no cumple las reglas de validación. |
| `400` | `sin_medio_apto` | Ningún medio cumple las reglas de negocio (por ejemplo, el peso supera la capacidad de la camioneta). |
| `503` | `modelo_no_disponible` | El servicio está arriba pero el artefacto del modelo no se pudo cargar. |
| `503` | `servicio_no_disponible` | El servicio `recomendar` no responde (lo devuelve el gateway). |

**Consumido por:** app_flutter (pantalla de recomendación, antes de registrar el pedido) y el
servicio `asistente` (intención `recomendar`).

### Reglas de negocio propuestas

**Estado:** Propuesto.

Las reglas tienen la última palabra sobre el modelo. Se evalúan en el servidor de
`recomendar` y descartan medios que no pueden hacer el envío.

| Regla | Enunciado |
|---|---|
| R1. Peso máximo | Un medio se descarta si `peso_kg` supera su peso máximo: dron 2 kg, bicicleta 8 kg, motocicleta 20 kg, camioneta 1000 kg. |
| R2. Distancia máxima | Un medio se descarta si `distancia_km` supera su distancia máxima: dron 10 km, bicicleta 8 km, motocicleta 40 km, camioneta 300 km. |
| R3. Tamaño del paquete | Un medio se descarta si el lado más largo de `dimensiones_cm` supera su límite: dron 40 cm, bicicleta 50 cm, motocicleta 60 cm, camioneta 200 cm. |
| R4. Urgencia | Si `urgente` es `true` y `distancia_km` es mayor que 3, se descarta la bicicleta. |

Cómo se decide el `medio_final`:

1. Si `medio_modelo` cumple todas las reglas, es el `medio_final` y
   `corregido_por_reglas` es `false`.
2. Si no las cumple, el `medio_final` es el medio apto con mayor probabilidad del modelo y
   `corregido_por_reglas` es `true`.
3. Si ningún medio es apto, responde `400 sin_medio_apto`.

Los límites de R1 y R2 deben coincidir con `peso_max_kg` y `distancia_max_km` del catálogo.
Los valores de esta tabla son ilustrativos hasta que el equipo los apruebe.

---

## Asistente

> **Estado de esta sección:** Propuesto (Int. 4). El asistente atiende en el rol de comprador:
> solo consulta, nunca registra pedidos ni cambia su estado. El clasificador de intenciones se
> entrena con un script aparte y el servicio solo carga el artefacto `.joblib`.

### Conversar con el asistente

| Campo | Valor |
|---|---|
| Servicio | asistente |
| Método | `POST` |
| Ruta | `/api/asistente/` |
| Responsable | Int. 4 |
| Estado | Propuesto |

**Solicitud**

```
POST /api/asistente/
```

```json
{
  "mensaje": "¿Dónde está mi pedido PQ-20261117-7KQ3?"
}
```

Reglas de validación:

- `mensaje` es obligatorio: texto de 1 a 500 caracteres, sin contar espacios al inicio y al final.
- Cada mensaje se atiende por separado; el asistente no guarda historial de la conversación.
  Los datos que necesita una intención (folio, peso, distancia, etc.) deben venir en el
  mismo mensaje. Si faltan, la respuesta los pide.

**Respuesta exitosa** (`200`)

```json
{
  "intencion": "rastrear",
  "respuesta": "Tu pedido PQ-20261117-7KQ3 está EN_CAMINO en motocicleta. Fecha límite: 2026-11-20."
}
```

| Campo | Descripción |
|---|---|
| `intencion` | Intención detectada: `rastrear`, `cotizar`, `recomendar`, `horarios`, `saludo` o `desconocida`. |
| `respuesta` | Texto para mostrar al comprador. |

**Cuando un servicio dependiente está caído**

Si `pedidos` o `recomendar` no responden dentro del tiempo límite (propuesto: 3 segundos) o
responden `503`, el asistente **no falla**: responde `200` con la intención detectada y una
respuesta que avisa del problema. Así la conversación sigue y las intenciones que no dependen
de otro servicio (`saludo`, `horarios`, `cotizar`) siguen funcionando.

```json
{
  "intencion": "rastrear",
  "respuesta": "En este momento no puedo consultar tu pedido. Intenta de nuevo en unos minutos."
}
```

Otras respuestas de los servicios dependientes también se traducen a texto con `200`: un `404`
de `pedidos` ("No encontré un pedido con ese folio") o un `400 sin_medio_apto` de `recomendar`
("Ningún medio puede llevar ese paquete").

**Errores**

| Código | `error` | Cuándo ocurre |
|---|---|---|
| `400` | `mensaje_vacio` | Falta `mensaje`, viene vacío o solo tiene espacios. |
| `400` | `datos_invalidos` | El cuerpo no es JSON válido, `mensaje` no es texto o supera 500 caracteres. |
| `503` | `modelo_no_disponible` | El servicio está arriba pero el clasificador de intenciones no se pudo cargar. |
| `503` | `servicio_no_disponible` | El servicio `asistente` no responde (lo devuelve el gateway). |

**Consumido por:** app_flutter (pantalla de chat).

### Intenciones propuestas

**Estado:** Propuesto.

Los datos vivos (estado de un pedido, recomendación) siempre se consultan por API en el
momento; nunca se responden con un texto guardado.

| Intención | Ejemplo de mensaje | De dónde sale la respuesta | Datos que extrae del mensaje |
|---|---|---|---|
| `saludo` | "Hola, buenas tardes" | Información fija del asistente. | Ninguno. |
| `horarios` | "¿A qué hora entregan?" | Información fija del asistente (horarios de atención y entrega). | Ninguno. |
| `cotizar` | "¿Cuánto cuesta enviar un paquete?" | Información fija del asistente: tarifas de referencia por medio y tipo de servicio, y aviso de que el costo exacto lo calcula el sistema al registrar el pedido. | Ninguno. |
| `rastrear` | "¿Dónde está mi pedido PQ-20261117-7KQ3?" | Consulta a la API de pedidos: `GET /api/pedidos/<folio>/`. | `folio` con formato `PQ-AAAAMMDD-XXXX`. Si no viene, la respuesta lo pide. |
| `recomendar` | "¿Cómo mando 3 kg a 6 km, 30x20x15 cm, urgente?" | Consulta a la API de recomendar: `POST /api/recomendar/`. | `peso_kg`, `distancia_km`, `dimensiones_cm` y `urgente` (falso si no se menciona). Si falta alguno de los obligatorios, la respuesta los pide. |
| `desconocida` | "¿Venden pizzas?" | Información fija del asistente: mensaje de ayuda con lo que sí puede hacer. | Ninguno. Se usa cuando la confianza del clasificador es baja. |

El asistente llama a los otros servicios por HTTP interno (`http://pedidos:8000/...` y
`http://recomendar:8000/...`), nunca importando su código ni leyendo su base de datos.

---

## Operaciones que el alcance mínimo debe cubrir

Lista de referencia del enunciado. Cada una necesita un contrato aprobado.
Marcadas: ya tienen contrato propuesto en este archivo, pendiente de aprobación.

- [x] Explorar y buscar en el catálogo
- [x] Obtener una recomendación
- [x] Registrar un pedido
- [x] Consultar un pedido por folio
- [x] Conversar con el asistente
