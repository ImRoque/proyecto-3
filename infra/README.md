# infra

**Propósito:** infraestructura de soporte y configuración del entorno local de los microservicios.

La orquestación está en el [`docker-compose.yml`](../docker-compose.yml) de la raíz, para que
todo se levante con un solo comando desde ahí.

## Contenido

| Archivo | Uso |
|---|---|
| `postgres/01-crear-bases.sh` | Crea un usuario y una base por servicio al iniciar PostgreSQL por primera vez. |
| `.gitattributes` | Fuerza fin de línea LF en los `.sh`, para que funcionen aunque se clone en Windows. |

## Contenedores

| Contenedor | Imagen | Puerto en el anfitrión | Notas |
|---|---|---|---|
| `postgres` | `postgres:16-alpine` | ninguno | Volumen `pgdata`. Healthcheck con `pg_isready`. |
| `catalogo`, `pedidos`, `recomendar`, `asistente` | se construyen desde `services/<servicio>` | ninguno | Escuchan en `8000` interno. Arrancan cuando PostgreSQL está sano. |
| `gateway` | `nginx:1.27-alpine` | `8080` | Ver [gateway/README.md](../gateway/README.md). |

## Persistencia

Un solo PostgreSQL 16 con una base por servicio (`docs/arquitectura.md`, sección 5.2):

| Base | Usuario | Contraseña (variable en `.env`) |
|---|---|---|
| `catalogo` | `catalogo` | `CATALOGO_DB_PASSWORD` |
| `pedidos` | `pedidos` | `PEDIDOS_DB_PASSWORD` |
| `recomendar` | `recomendar` | `RECOMENDAR_DB_PASSWORD` |
| `asistente` | `asistente` | `ASISTENTE_DB_PASSWORD` |

- Cada usuario es dueño solo de su base y no tiene permiso `CONNECT` sobre las demás.
- Cada usuario tiene `CREATEDB` para que `python manage.py test` pueda crear y borrar su base
  temporal `test_<servicio>`. Si tu volumen es anterior a este cambio, borra el volumen
  (`docker compose down -v`) o da el permiso a mano:
  `docker compose exec postgres psql -U postgres -c 'ALTER ROLE <servicio> CREATEDB;'`
- Compose pasa a cada servicio `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST=postgres` y `DB_PORT`.
- El script de `postgres/` **solo corre cuando el volumen está vacío**. Si cambias el script o
  las contraseñas, borra el volumen (se pierden los datos locales):

  ```bash
  docker compose down -v
  docker compose up -d --build
  ```

- En Compose **todos los servicios usan PostgreSQL**: el `settings.py` de cada uno elige
  PostgreSQL cuando existe `DB_NAME`, y Compose siempre la define. SQLite solo se usa al correr
  un servicio suelto fuera de Compose (sin `DB_NAME`).
- Las migraciones se aplican solas al iniciar cada contenedor:

  | Servicio | Al arrancar |
  |---|---|
  | `catalogo` | `migrate` + `loaddata catalogo_inicial.json` (4 medios y 3 tipos de servicio) desde su `entrypoint.sh`. La carga es idempotente: actualiza por clave, no duplica. |
  | `pedidos` | `migrate` desde su `entrypoint.sh`. |
  | `recomendar`, `asistente` | `migrate` desde el `command` de `docker-compose.yml`. Hoy no tienen modelos (no crean tablas), pero así quedan listos y validan la conexión al arrancar. |

- Los datos viven en el volumen `pgdata`: sobreviven a `docker compose restart` y a
  `docker compose down` (sin `-v`).

### Comprobar la persistencia

```bash
docker compose down -v && docker compose up -d --build
curl -X POST http://localhost:8080/api/pedidos/ -H "Content-Type: application/json"   -H "Idempotency-Key: $(uuidgen)" -d '{...cuerpo de docs/api.md...}'
docker compose restart            # o: docker compose down && docker compose up -d
curl http://localhost:8080/api/pedidos/<folio>/    # debe responder 200 con el mismo pedido
docker compose exec postgres psql -U postgres -d pedidos -c 'select folio, estado from pedidos_pedido;'
```

## Variables de entorno

Todas están en [`.env.example`](../.env.example) con valores de ejemplo. Copia el archivo como
`.env`; Compose se niega a arrancar si falta alguna contraseña o `SECRET_KEY`.
`.env` está en `.gitignore` y nunca se sube.

## Comandos útiles

```bash
docker compose ps                     # estado de los contenedores
docker compose logs -f gateway        # logs de un contenedor
docker compose stop <servicio>        # apagar un servicio (demo de fallo parcial)
docker compose start <servicio>       # volver a levantarlo
docker compose down                   # apagar todo (conserva la base)
docker compose exec postgres psql -U postgres   # consola de PostgreSQL
docker compose exec <servicio> python manage.py test   # pruebas contra PostgreSQL
```
