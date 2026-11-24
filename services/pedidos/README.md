# services/pedidos

**Propósito:** microservicio responsable de registrar pedidos y consultarlos por folio.



## Estado actual

Proyecto Django 5 (proyecto `config`, app `pedidos`) que implementa la sección "Pedidos"
de `docs/api.md`:

| Método | Ruta | Qué hace |
|---|---|---|
| `GET` | `/api/pedidos/health/` | Salud: `200 {"servicio": "pedidos", "ok": true}` |
| `POST` | `/api/pedidos/` | Registra un pedido (encabezado `Idempotency-Key` obligatorio) |
| `GET` | `/api/pedidos/<folio>/` | Consulta por folio, solo datos mínimos |
| `PATCH` | `/api/pedidos/<folio>/estado/` | Cambia el estado si la transición es válida |

Organización del código en `pedidos/`:

| Archivo | Responsabilidad |
|---|---|
| `views.py` | Lee la petición y arma la respuesta. No usa el ORM. |
| `confirmacion.py` | `ConfirmacionPedido` (Facade): valida, revisa la clave, consulta el catálogo, calcula el costo y guarda. |
| `repositorio.py` | `PedidoRepositorio` (Repository): acceso a datos y forma del JSON. |
| `validacion.py` | Reglas de validación del cuerpo y del encabezado. |
| `cliente_catalogo.py` | Llamadas HTTP a `catalogo` con tiempo límite. |
| `estados.py` | Estados y transiciones válidas. |
| `folio.py` | Generación y formato del folio `PQ-AAAAMMDD-XXXX`. |

**Doble clic (`Idempotency-Key`).** La clave se guarda con restricción única en la base. Si
llega repetida con el mismo cuerpo se responde `200` con el mismo pedido; con otro cuerpo,
`409 idempotency_key_reutilizada`. Si dos peticiones con la misma clave llegan a la vez, la
base rechaza el segundo `INSERT` y esa petición responde con el pedido de la primera.

**Dependencia de `catalogo`.** Para validar el medio y calcular el costo, `pedidos` consulta
`catalogo` por HTTP. Si no responde dentro de `CATALOGO_TIMEOUT`, el registro responde
`503 servicio_no_disponible` y no crea nada; la consulta y el cambio de estado siguen
funcionando porque no lo necesitan.
El límite cubre toda la llamada (búsqueda DNS, conexión y lectura), así que ni un
`catalogo` apagado ni uno lento dejan colgado el registro. Una respuesta cortada o que no es
JSON cuenta igual como `503`.

## Variables de entorno

| Variable | Uso | Por defecto |
|---|---|---|
| `SECRET_KEY` | Clave de Django | Valor de desarrollo (cámbiala fuera de tu equipo) |
| `DEBUG` | `True` o `False` | `False` |
| `ALLOWED_HOSTS` | Hosts permitidos, separados por coma | `localhost,127.0.0.1` |
| `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT` | PostgreSQL | Si no hay `DB_NAME`, usa SQLite |
| `CATALOGO_URL` | URL interna del servicio catalogo | `http://catalogo:8000` |
| `CATALOGO_TIMEOUT` | Tiempo límite hacia catalogo, en segundos | `3` |
| `GUNICORN_WORKERS` | Procesos de gunicorn en el contenedor | `3` |

Ver `.env.example`.

## Correrlo solo (sin Docker)

Desde `services/pedidos/`:

```bash
python -m venv .venv
source .venv/bin/activate        # En Windows: .venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate
# Para registrar pedidos hace falta catalogo; si corre suelto en el 8001:
CATALOGO_URL=http://localhost:8001 python manage.py runserver 8000
```

```bash
curl -i http://localhost:8000/api/pedidos/health/
```

## Correrlo con Docker

Desde `services/pedidos/`:

```bash
docker build -t proyecto3-pedidos .
docker run --rm -p 8000:8000 proyecto3-pedidos   # aplica migraciones al arrancar
```

```bash
curl -i http://localhost:8000/api/pedidos/health/
```

Dentro de Docker Compose, agrega el nombre del servicio a los hosts permitidos, por ejemplo
`ALLOWED_HOSTS=pedidos,localhost`.

## Pruebas

Desde `services/pedidos/`, con las dependencias instaladas:

```bash
python manage.py test
```

Las pruebas no necesitan `catalogo`: lo sustituyen por un catálogo falso con los mismos
valores del fixture de `services/catalogo/`.

## Probarlo por el gateway

Con todo levantado (`docker compose up -d --build` desde la raíz):

```bash
curl -i -X POST http://localhost:8080/api/pedidos/   -H "Content-Type: application/json; charset=utf-8"   -H "Idempotency-Key: 3f6c2a1e-8b7d-4c1a-9e2f-5a4b3c2d1e0f"   -d '{"origen": "Av. Juárez 100", "destino": "Calle Hidalgo 25", "distancia_km": 8.5,
       "peso_kg": 2.3, "dimensiones_cm": {"largo": 30, "ancho": 20, "alto": 15},
       "urgente": false, "seguro": true, "fecha_limite": "2026-12-20",
       "medio": "motocicleta", "tipo_servicio": "express"}'

curl -i http://localhost:8080/api/pedidos/<folio>/
curl -i -X PATCH http://localhost:8080/api/pedidos/<folio>/estado/   -H "Content-Type: application/json; charset=utf-8" -d '{"estado": "EN_CAMINO"}'
```
