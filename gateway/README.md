# gateway

**Propósito:** punto único de entrada para los clientes web y móvil. Flutter solo conoce
esta dirección, nunca las internas de los servicios.

**Tecnología:** nginx 1.27 (imagen `nginx:1.27-alpine`). Configuración en [`nginx.conf`](nginx.conf).
Se levanta junto con todo lo demás desde el `docker-compose.yml` de la raíz.

## Enrutamiento

| Prefijo | Destino interno |
|---|---|
| `/api/catalogo/` | `catalogo:8000` |
| `/api/pedidos/` | `pedidos:8000` |
| `/api/recomendar/` | `recomendar:8000` |
| `/api/asistente/` | `asistente:8000` |
| cualquier otra ruta | `404 {"error": "ruta_no_encontrada", ...}` |

El gateway conserva la ruta completa: `GET /api/pedidos/PQ-.../` llega igual a `pedidos`.
Se publica en el puerto `8080` del anfitrión (configurable con `GATEWAY_PORT` en `.env`).

## CORS

- `Access-Control-Allow-Origin: *` en todas las respuestas, incluidos los errores.
- Métodos: `GET, POST, PATCH, OPTIONS`. Encabezados: `Content-Type, Idempotency-Key`.
- El preflight `OPTIONS` lo responde el gateway con `204`, sin llegar al servicio.
- Si un servicio manda sus propios encabezados CORS, el gateway los ignora.

## Servicio no disponible

- El nombre del servicio se resuelve en cada petición con el DNS interno de Docker
  (`resolver 127.0.0.11` + variable en `proxy_pass`). Por eso el gateway arranca aunque un
  servicio esté apagado y lo vuelve a encontrar cuando se levanta.
- Si el gateway no puede hablar con el servicio (apagado, sin DNS o sin respuesta a tiempo),
  **solo esa ruta** responde:

  ```
  HTTP/1.1 503
  {"error": "servicio_no_disponible", "detalle": "El servicio <servicio> no respondió"}
  ```

- Los `503` que genere el propio servicio (por ejemplo `modelo_no_disponible`) pasan sin cambios.

## Tiempos límite

| Parámetro | Valor |
|---|---|
| Conexión al servicio (`proxy_connect_timeout`) | 3 s |
| Envío de la solicitud (`proxy_send_timeout`) | 10 s |
| Lectura de la respuesta (`proxy_read_timeout`) | 10 s |
| Resolución DNS (`resolver_timeout`) | 2 s |

## Probar

```bash
curl -i http://localhost:8080/api/catalogo/health/
docker compose stop recomendar
curl -i http://localhost:8080/api/recomendar/health/   # 503
curl -i http://localhost:8080/api/pedidos/health/      # sigue en 200
docker compose start recomendar
```

Demo completa de fallo parcial: `./scripts/demo_fallo_parcial.sh` (ver
[docs/arquitectura.md](../docs/arquitectura.md#53-fallos-parciales), 5.3).

Validar la sintaxis sin levantar nada:

```bash
docker compose run --rm --no-deps gateway nginx -t
```
